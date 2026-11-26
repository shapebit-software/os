// installerctl: command-line client of the installer backend, for tests and
// debugging. It uses the same D-Bus interface as the UI.
// Usage: installerctl [--session] capabilities
//        installerctl [--session] disks
//        installerctl [--session] networks
//        installerctl [--session] install --disk ID --user NAME --password-file FILE
//                     --recovery-key-file FILE [--real-name NAME] [--home-size BYTES]
//                     [--locale LOCALE] [--keyboard-layout LAYOUT] [--time-zone ZONE]
// --session talks to `installer-backend --simulate`. `install` erases the disk
// without asking, waits for the result, and acknowledges the recovery key.
#include "installerinterface.h"
#include "names.h"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextStream>

#include <unistd.h>

namespace {

QTextStream out(stdout);
QTextStream err(stderr);

template <typename Reply>
bool check(Reply &reply)
{
    reply.waitForFinished();
    if (reply.isError())
        err << "error: " << reply.error().message() << Qt::endl;
    return !reply.isError();
}

void print(const QVariantMap &map)
{
    out << QJsonDocument(QJsonObject::fromVariantMap(map)).toJson(QJsonDocument::Compact) << Qt::endl;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addOption({QStringLiteral("session"), QStringLiteral("Use the session bus (simulated backend).")});
    parser.addOption({QStringLiteral("disk"), QStringLiteral("Id of the disk to erase."), QStringLiteral("id")});
    parser.addOption({QStringLiteral("user"), QStringLiteral("User name of the first owner."), QStringLiteral("name")});
    parser.addOption({QStringLiteral("real-name"), QStringLiteral("Full name of the first owner."), QStringLiteral("name")});
    parser.addOption({QStringLiteral("home-size"), QStringLiteral("Size of the owner's home, in bytes."), QStringLiteral("bytes")});
    parser.addOption({QStringLiteral("locale"), QStringLiteral("Locale of the installed system."), QStringLiteral("locale")});
    parser.addOption({QStringLiteral("keyboard-layout"), QStringLiteral("XKB layout, with its variant in parentheses."), QStringLiteral("layout")});
    parser.addOption({QStringLiteral("time-zone"), QStringLiteral("Time zone of the installed system."), QStringLiteral("zone")});
    parser.addOption({QStringLiteral("password-file"), QStringLiteral("File with the owner's password."), QStringLiteral("file")});
    parser.addOption({QStringLiteral("recovery-key-file"), QStringLiteral("Where to save the recovery key."), QStringLiteral("file")});
    parser.addPositionalArgument(QStringLiteral("command"), QStringLiteral("capabilities, disks, networks, or install"));
    parser.process(app);
    const QString command = parser.positionalArguments().value(0);

    registerTypes();
    software::shapebit::Installer1 installer(Names::service, Names::path, installerBus(parser.isSet(QStringLiteral("session"))));
    installer.setTimeout(30 * 1000);

    if (command == QLatin1String("capabilities")) {
        auto reply = installer.GetCapabilities();
        if (!check(reply))
            return 1;
        print(reply.value());
        return 0;
    }
    if (command == QLatin1String("disks")) {
        auto reply = installer.ListDisks();
        if (!check(reply))
            return 1;
        for (const QVariantMap &disk : reply.value())
            print(disk);
        return 0;
    }
    if (command == QLatin1String("networks")) {
        auto reply = installer.ListNetworks();
        if (!check(reply))
            return 1;
        for (const QVariantMap &network : reply.value())
            print(network);
        return 0;
    }
    if (command != QLatin1String("install"))
        parser.showHelp(2);

    QFile passwordFile(parser.value(QStringLiteral("password-file")));
    QFile keyFile(parser.value(QStringLiteral("recovery-key-file")));
    if (!passwordFile.open(QIODevice::ReadOnly)
        || !keyFile.open(QIODevice::WriteOnly, QFileDevice::ReadOwner | QFileDevice::WriteOwner)) {
        err << "error: --password-file must be readable and --recovery-key-file writable" << Qt::endl;
        return 2;
    }
    QByteArray password = passwordFile.readAll();
    if (password.endsWith('\n'))
        password.chop(1);

    QVariantMap plan{{QStringLiteral("disk"), parser.value(QStringLiteral("disk"))},
                     {QStringLiteral("userName"), parser.value(QStringLiteral("user"))}};
    if (parser.isSet(QStringLiteral("real-name")))
        plan.insert(QStringLiteral("realName"), parser.value(QStringLiteral("real-name")));
    if (parser.isSet(QStringLiteral("home-size")))
        plan.insert(QStringLiteral("homeSize"), parser.value(QStringLiteral("home-size")).toULongLong());
    for (const auto &[option, key] : {std::pair{"locale", "locale"}, {"keyboard-layout", "keyboardLayout"}, {"time-zone", "timeZone"}}) {
        if (parser.isSet(QLatin1String(option)))
            plan.insert(QLatin1String(key), parser.value(QLatin1String(option)));
    }
    auto planned = installer.SetPlan(plan);
    if (!check(planned))
        return 1;

    auto secret = installer.OpenSecret(QStringLiteral("owner-password"));
    if (!check(secret))
        return 1;
    {
        QFile pipe;
        if (!pipe.open(::dup(secret.value().fileDescriptor()), QIODevice::WriteOnly, QFileDevice::AutoCloseHandle)
            || pipe.write(password) != password.size()) {
            err << "error: could not send the password" << Qt::endl;
            return 1;
        }
    }
    // The reply holds the other copy of the write end; the backend sees the
    // end of the password only when both are closed.
    secret = QDBusPendingReply<QDBusUnixFileDescriptor>();

    QObject::connect(&installer, &software::shapebit::Installer1::Failed, &app,
                     [&](const QString &code, const QString &message) {
        err << "error: " << code << ": " << message << Qt::endl;
        app.exit(1);
    });
    QObject::connect(&installer, &software::shapebit::Installer1::PhaseChanged, &app, [&](const QString &phase) {
        out << phase << Qt::endl;
        if (phase != Phase::awaitingAcknowledgement)
            return;
        auto key = installer.TakeRecoveryKey();
        if (!check(key))
            return app.exit(1);
        QFile pipe;
        if (!pipe.open(::dup(key.value().fileDescriptor()), QIODevice::ReadOnly, QFileDevice::AutoCloseHandle))
            return app.exit(1);
        keyFile.write(pipe.readAll());
        keyFile.close();
        auto acknowledged = installer.Acknowledge();
        app.exit(check(acknowledged) ? 0 : 1);
    });

    auto started = installer.Install(parser.value(QStringLiteral("disk")));
    if (!check(started))
        return 1;
    return app.exec();
}
