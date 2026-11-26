// Clicks through every page against `installer-backend --simulate`.
// Run under `dbus-run-session` with QT_QPA_PLATFORM=offscreen (see CMakeLists.txt).
// With INSTALLER_SCREENSHOTS set to a directory, saves a picture of each page.
#include "backend.h"
#include "display.h"
#include "keyboard.h"
#include "names.h"

#include <QColor>
#include <QDBusConnectionInterface>
#include <QKeyEvent>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTest>

#include <algorithm>

class UiTest : public QObject
{
    Q_OBJECT
private slots:
    void initTestCase()
    {
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        environment.insert("INSTALLER_SIMULATE_STEP_MS", "50");
        m_backend.setProcessEnvironment(environment);
        m_backend.setProcessChannelMode(QProcess::ForwardedChannels);
        m_backend.start(INSTALLER_BACKEND, {"--simulate"});
        QTRY_VERIFY(QDBusConnection::sessionBus().interface()->isServiceRegistered(Names::service));
        Backend::session = true;
        registerTypes();
    }

    void cleanupTestCase()
    {
        m_backend.kill();
        m_backend.waitForFinished();
    }

    // The OS tests wait for this line before they press keys on a page.
    void pageSaysWhenReady()
    {
        QTest::ignoreMessage(QtInfoMsg, "Installer page: welcome");
        QQmlApplicationEngine engine;
        engine.loadFromModule("Installer", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        auto *stack = window->findChild<QObject *>("stack");
        auto *current = stack->property("currentItem").value<QObject *>();

        QTest::ignoreMessage(QtInfoMsg, "Installer page: keyboard");
        QMetaObject::invokeMethod(current, "next");
        QTRY_VERIFY(!stack->property("busy").toBool());
    }

    // The colors come from Colors, the system's module of colors, which Qt
    // must find; a binding that cannot reach it only warns and leaves the
    // color black. The default accent is the brand's violet.
    void colorsComeFromTheSystemsList()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Installer", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *theme = engine.singletonInstance<QObject *>("Installer", "Theme");
        QVERIFY(theme);
        QCOMPARE(theme->property("accent").value<QColor>().name(), "#5b2fd6");
        QCOMPARE(theme->property("background").value<QColor>().name(), "#1f1a3c");
        QCOMPARE(theme->property("text").value<QColor>().name(), "#ffffff");
        // The accent as text is lighter than the accent itself, to read on night.
        QVERIFY(theme->property("link").value<QColor>().lightnessF()
                > theme->property("accent").value<QColor>().lightnessF());
        // Eight bits a channel: with fewer, the backdrop shows bands, as it
        // did under cage, which offers 16-bit configs first.
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QCOMPARE(window->requestedFormat().redBufferSize(), 8);
        QCOMPARE(window->requestedFormat().greenBufferSize(), 8);
        QCOMPARE(window->requestedFormat().blueBufferSize(), 8);
    }

    void installsFromFirstPageToLast()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Installer", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        m_window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        m_stack = m_window->findChild<QObject *>("stack");
        QVERIFY(m_stack);
        auto *backend = engine.singletonInstance<Backend *>("Installer", "Backend");

        // The logo is the first page's heading.
        QVERIFY(heading().isEmpty());
        // The header's logo and the page's, loaded from the module's resources.
        const auto logos = m_window->findChildren<QObject *>("logo");
        QCOMPARE(logos.size(), 2);
        for (const QObject *logo : logos)
            QTRY_COMPARE(logo->property("status").toInt(), 1); // Image.Ready
        QCOMPARE(visibleLogos(), 1); // The page's: the header leaves it out.
        QCOMPARE(field("language")->property("currentText").toString(), "American English (US)");
        // The keyboard works before anything is clicked: Enter goes on.
        QVERIFY(QTest::qWaitForWindowActive(m_window));
        snapshot();
        QTest::keyClick(m_window, Qt::Key_Return);

        QCOMPARE(heading(), "Keyboard layout");
        QTRY_COMPARE(visibleLogos(), 1); // The header's.
        QCOMPARE(field("layoutName")->property("text").toString(), "English (US)");
        field("search")->setProperty("text", "french azerty");
        QCOMPARE(field("layouts")->property("count").toInt(), 2); // With and without AFNOR.
        // Down in the search field chooses the first match; which of the two
        // that is depends on the collation.
        auto *keyboard = engine.singletonInstance<Keyboard *>("Installer", "Keyboard");
        QTest::keyClick(m_window, Qt::Key_Down);
        QVERIFY(QStringList({"fr(azerty)", "fr(afnor)"}).contains(keyboard->layout()));
        QCOMPARE(keyboard->rows().at(1).toStringList().first(), "A");
        next();

        QCOMPARE(heading(), "Connect to a network");
        QCOMPARE(page()->property("nextText").toString(), "Skip for now");
        page()->setProperty("selected", "Simulated Home");
        QTRY_VERIFY(field("wifiPassword")->property("visible").toBool());
        field("wifiPassword")->setProperty("text", "wrong");
        QVERIFY(QMetaObject::invokeMethod(field("connect"), "clicked"));
        QCOMPARE(field("networkError")->property("text").toString(), "The password is not correct");
        // Enter in the password field connects and stays on the page.
        field("wifiPassword")->setProperty("text", "right");
        QVERIFY(QTest::qWaitForWindowActive(m_window));
        QTRY_VERIFY(m_window->activeFocusItem() && m_window->activeFocusItem()->property("echoMode").isValid());
        QTest::keyClick(m_window, Qt::Key_Return);
        QCOMPARE(page()->property("nextText").toString(), "Continue");
        QCOMPARE(heading(), "Connect to a network");
        // Enter elsewhere goes on.
        snapshot();
        QTest::keyClick(m_window, Qt::Key_Return);

        QCOMPARE(heading(), "Time zone");
        field("search")->setProperty("text", "warsaw");
        QCOMPARE(field("zones")->property("count").toInt(), 1);
        page()->setProperty("timeZone", "Europe/Warsaw");
        QCOMPARE(field("city")->property("text").toString(), "Warsaw");
        next();

        QCOMPARE(heading(), "Create your account");
        field("firstName")->setProperty("text", "Zoë");
        field("lastName")->setProperty("text", "Eloper");
        QCOMPARE(field("userName")->property("text").toString(), "zoe");
        // The chosen layout is French: the key that types "q" elsewhere types "a".
        QVERIFY(QTest::qWaitForWindowActive(m_window));
        // The first field has the focus, so the user can type at once.
        QObject *focused = nullptr;
        QTRY_VERIFY((focused = m_window->activeFocusItem()) && focused->property("echoMode").isValid());
        focused->setProperty("text", "");
        const quint32 keyQ = 16 + 8;
        QKeyEvent press(QEvent::KeyPress, Qt::Key_Q, Qt::NoModifier, keyQ, 0, 0, "q");
        QKeyEvent release(QEvent::KeyRelease, Qt::Key_Q, Qt::NoModifier, keyQ, 0, 0, "q");
        QCoreApplication::sendEvent(m_window, &press);
        QCoreApplication::sendEvent(m_window, &release);
        QCOMPARE(focused->property("text").toString(), "a");
        field("firstName")->setProperty("text", "Zoë");
        field("password")->setProperty("text", "secret1");
        QVERIFY(!nextEnabled()); // Too short.
        field("password")->setProperty("text", "secret12");
        field("confirm")->setProperty("text", "different");
        QVERIFY(!nextEnabled());
        field("confirm")->setProperty("text", "secret12");
        next();

        QCOMPARE(heading(), "Choose a disk");
        QVERIFY(!nextEnabled()); // Nothing is selected.
        // Tab reaches the first disk and Space chooses it.
        QTRY_VERIFY(!m_stack->property("busy").toBool());
        QVERIFY(!field("understood")->property("enabled").toBool());
        QTest::keyClick(m_window, Qt::Key_Tab);
        QTest::keyClick(m_window, Qt::Key_Space);
        QVERIFY(field("understood")->property("enabled").toBool());
        page()->setProperty("selected", backend->disks().first());
        QVERIFY(!nextEnabled()); // Not confirmed.
        field("understood")->setProperty("checked", true);
        page()->setProperty("selected", backend->disks().at(1));
        QVERIFY(!nextEnabled()); // The confirmation was for the other disk.
        field("understood")->setProperty("checked", true);
        next();

        QTRY_COMPARE(heading(), "Installing ShapeBit");
        snapshot();
        QTRY_COMPARE(heading(), "Save your recovery key");
        QVERIFY(field("recoveryKey")->property("text").toString().startsWith("simulated-recovery-key"));
        QVERIFY(!nextEnabled()); // Not saved.
        field("saved")->setProperty("checked", true);
        next();

        QTRY_COMPARE(heading(), "ShapeBit is installed");
        snapshot();
        QCOMPARE(backend->phase(), Phase::completed);
    }

private:
    QObject *page() const { return m_stack->property("currentItem").value<QObject *>(); }
    QString heading() const { return page()->property("heading").toString(); }
    qsizetype visibleLogos() const
    {
        const auto logos = m_window->findChildren<QObject *>("logo");
        return std::count_if(logos.begin(), logos.end(), [](const QObject *logo) { return logo->property("visible").toBool(); });
    }
    bool nextEnabled() const { return page()->property("nextEnabled").toBool(); }
    QObject *field(const char *name) const { return find(qobject_cast<QQuickItem *>(page()), QLatin1String(name)); }
    // Searches the items as shown: list entries are not QObject children of their list.
    static QQuickItem *find(QQuickItem *item, QLatin1String name)
    {
        if (item->objectName() == name)
            return item;
        for (QQuickItem *child : item->childItems()) {
            if (QQuickItem *found = find(child, name))
                return found;
        }
        return nullptr;
    }
    void next()
    {
        QVERIFY(nextEnabled());
        snapshot();
        QMetaObject::invokeMethod(page(), "next");
    }

    void snapshot()
    {
        const QString directory = qEnvironmentVariable("INSTALLER_SCREENSHOTS");
        if (directory.isEmpty())
            return;
        QTRY_VERIFY(!m_stack->property("busy").toBool()); // The page transition has ended.
        m_window->grabWindow().save(QStringLiteral("%1/%2-%3.png").arg(directory).arg(++m_snapshots).arg(heading().isEmpty() ? QStringLiteral("Welcome") : heading().section(QLatin1Char(' '), 0, 0)));
    }

    QProcess m_backend;
    QQuickWindow *m_window = nullptr;
    int m_snapshots = 0;
    QObject *m_stack = nullptr;
};

// As the installer's main does, before the application starts.
int main(int argc, char *argv[])
{
    requestFullColor();
    QGuiApplication app(argc, argv);
    UiTest test;
    QTEST_SET_MAIN_SOURCE_PATH
    return QTest::qExec(&test, argc, argv);
}
#include "tst_ui.moc"
