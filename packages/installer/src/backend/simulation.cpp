#include "simulation.h"

#include "command.h"
#include "names.h"

#include <QCoreApplication>

namespace {
const QStringList phases{Phase::validating, Phase::preparing, Phase::creatingStorage,
                         Phase::installingSystem, Phase::configuring, Phase::verifying};
}

SimulatedEngine::SimulatedEngine(QObject *parent) : Engine(parent)
{
    // INSTALLER_SIMULATE_STEP_MS shortens the phases for tests.
    m_timer.setInterval(qEnvironmentVariableIntValue("INSTALLER_SIMULATE_STEP_MS") ?: 1500);
    connect(&m_timer, &QTimer::timeout, this, &SimulatedEngine::advance);
}

QVariantMap SimulatedEngine::capabilities()
{
    return {{QStringLiteral("uefi"), true}, {QStringLiteral("secureBoot"), true},
            {QStringLiteral("setupMode"), false}, {QStringLiteral("tpm2"), true},
            {QStringLiteral("locales"), QStringList{QStringLiteral("de_DE.UTF-8"), QStringLiteral("en_GB.UTF-8"),
                                                    QStringLiteral("en_US.UTF-8"), QStringLiteral("pl_PL.UTF-8")}}};
}

QList<Disk> SimulatedEngine::disks()
{
    const qint64 gb = 1000LL * 1000 * 1000;
    return {
        {QStringLiteral("wwn-0x5000000000000001"), QStringLiteral("/dev/nvme0n1"), QStringLiteral("Simulated NVMe 512GB"),
         QStringLiteral("nvme"), 512 * gb, false, {}},
        {QStringLiteral("serial-SIM0002"), QStringLiteral("/dev/sda"), QStringLiteral("Simulated USB Disk"),
         QStringLiteral("usb"), 64 * gb, true, {}},
        {QStringLiteral("serial-SIM0003"), QStringLiteral("/dev/sdb"), QStringLiteral("Installer medium"),
         QStringLiteral("usb"), 32 * gb, true, QStringLiteral("In use by the running system")},
    };
}

QList<QVariantMap> SimulatedEngine::networks()
{
    QList<QVariantMap> result;
    const auto add = [&](const QString &ssid, int strength, const QString &security) {
        result.append({{QStringLiteral("ssid"), ssid}, {QStringLiteral("strength"), strength},
                       {QStringLiteral("security"), security}, {QStringLiteral("connected"), ssid == m_connected}});
    };
    add(QStringLiteral("Simulated Home"), 90, QStringLiteral("WPA3"));
    add(QStringLiteral("Simulated Home 5G"), 60, QStringLiteral("WPA3"));
    add(QStringLiteral("Simulated Café"), 55, QString());
    add(QStringLiteral("Simulated Printer"), 20, QStringLiteral("WPA2"));
    return result;
}

void SimulatedEngine::connectNetwork(const QString &ssid, const QByteArray &password)
{
    // The password "wrong" exercises the error path.
    if (password == "wrong")
        throw Failure{QStringLiteral("connection-failed"), QStringLiteral("The password is not correct")};
    for (const QVariantMap &network : networks()) {
        if (network.value(QStringLiteral("ssid")) == ssid
            && network.value(QStringLiteral("security")).toString().isEmpty() == password.isEmpty()) {
            m_connected = ssid;
            return;
        }
    }
    throw Failure{QStringLiteral("connection-failed"), QStringLiteral("Could not connect to %1").arg(ssid)};
}

void SimulatedEngine::install(const Plan &plan, const QByteArray &)
{
    // A user named "fail" exercises the error path.
    m_step = plan.userName == QLatin1String("fail") ? -1 : 0;
    m_timer.start();
}

void SimulatedEngine::advance()
{
    if (m_step < 0) {
        m_timer.stop();
        emit failed(QStringLiteral("simulated"), QStringLiteral("Simulated failure"));
    } else if (++m_step < phases.size()) {
        emit phaseChanged(phases.at(m_step));
    } else {
        m_timer.stop();
        emit finished("simulated-recovery-key-simulated-recovery-key-simulated-recovery-key");
    }
}

void SimulatedEngine::cancel()
{
    // Only the first two phases can be cancelled, as on a real machine.
    if (m_timer.isActive() && m_step < 2) {
        m_timer.stop();
        emit failed(QStringLiteral("cancelled"), QStringLiteral("The installation was cancelled"));
    }
}

void SimulatedEngine::reboot()
{
    QCoreApplication::quit();
}
