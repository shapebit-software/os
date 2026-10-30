// installer: the unprivileged Qt Quick frontend of the installer.
// Usage: installer            talks to the backend on the system bus
//        installer --session  talks to `installer-backend --simulate`
#include "backend.h"
#include "names.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    Backend::session = app.arguments().contains(QStringLiteral("--session"));
    registerTypes();
    // The pages draw their own controls on top of the unstyled ones.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Installer", "Main");
    return app.exec();
}
