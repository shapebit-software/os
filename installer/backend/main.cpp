// installer-backend: the privileged half of the installer.
// Usage: installer-backend             on the system bus, installs for real
//        installer-backend --simulate  on the session bus, changes nothing
#include "installer.h"
#include "installeradaptor.h"
#include "names.h"
#include "simulation.h"
#include "system.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const bool simulate = app.arguments().contains(QStringLiteral("--simulate"));
    registerTypes();

    Engine *engine = simulate ? static_cast<Engine *>(new SimulatedEngine(&app)) : new SystemEngine(&app);
    Installer installer(engine);
    new Installer1Adaptor(&installer);

    QDBusConnection bus = installerBus(simulate);
    if (!bus.registerObject(Names::path, &installer) || !bus.registerService(Names::service)) {
        qCritical("Could not register on D-Bus: %s", qPrintable(bus.lastError().message()));
        return 1;
    }
    return app.exec();
}
