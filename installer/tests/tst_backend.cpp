// Backend logic that needs no D-Bus and no disk: disk eligibility, plan
// validation, and the D-Bus object's rules, driven on the simulated engine.
#include "command.h"
#include "installer.h"
#include "names.h"
#include "simulation.h"

#include <QFile>
#include <QTest>

#include <unistd.h>

namespace {

const QByteArray lsblk = R"({"blockdevices": [
  {"name":"nvme0n1","path":"/dev/nvme0n1","type":"disk","size":512110190592,"model":"Good  Disk ","serial":"S1","wwn":"eui.01","tran":"nvme","ro":false,"rm":false,"mountpoints":[null],
   "children":[{"name":"nvme0n1p1","path":"/dev/nvme0n1p1","type":"part","size":1,"mountpoints":[null]}]},
  {"name":"sda","path":"/dev/sda","type":"disk","size":64000000000,"model":"Medium","serial":"S2","wwn":null,"tran":"usb","ro":false,"rm":true,"mountpoints":[null],
   "children":[{"name":"sda2","path":"/dev/sda2","type":"part","size":1,"mountpoints":["/sysroot","/var"]}]},
  {"name":"sdb","path":"/dev/sdb","type":"disk","size":8000000000,"model":"Small","serial":"S3","wwn":null,"tran":"usb","ro":false,"rm":true,"mountpoints":[null]},
  {"name":"sdc","path":"/dev/sdc","type":"disk","size":64000000000,"model":"Anonymous","serial":null,"wwn":null,"tran":"usb","ro":false,"rm":true,"mountpoints":[null]},
  {"name":"sdd","path":"/dev/sdd","type":"disk","size":64000000000,"model":"Locked","serial":"S5","wwn":null,"tran":"sata","ro":true,"rm":false,"mountpoints":[null]},
  {"name":"zram0","path":"/dev/zram0","type":"disk","size":4000000000,"model":null,"serial":null,"wwn":null,"tran":null,"ro":false,"rm":false,"mountpoints":["[SWAP]"]},
  {"name":"sr0","path":"/dev/sr0","type":"rom","size":1,"model":"CD","serial":"S7","wwn":null,"tran":"sata","ro":false,"rm":true,"mountpoints":[null]}
]})";

const QString goodDisk = QStringLiteral("wwn-0x5000000000000001"); // In the simulated engine.

QByteArray code(const std::function<void()> &function)
{
    try {
        function();
    } catch (const Failure &failure) {
        return failure.code.toUtf8();
    }
    return "ok";
}

} // namespace

class BackendTest : public QObject
{
    Q_OBJECT
private slots:
    void initTestCase() { qputenv("INSTALLER_SIMULATE_STEP_MS", "1"); }

    void listsOnlyDisks()
    {
        const QList<Disk> disks = parseDisks(lsblk);
        QStringList paths;
        for (const Disk &disk : disks)
            paths.append(disk.path);
        QCOMPARE(paths, (QStringList{"/dev/nvme0n1", "/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"}));
    }

    void identifiesDisksByWwnOrSerial()
    {
        const QList<Disk> disks = parseDisks(lsblk);
        QCOMPARE(disks.at(0).id, "wwn-eui.01");
        QCOMPARE(disks.at(0).model, "Good Disk");
        QCOMPARE(disks.at(1).id, "serial-S2");
        QCOMPARE(disks.at(3).id, "");
    }

    void refusesUnsuitableDisks()
    {
        const QList<Disk> disks = parseDisks(lsblk);
        QVERIFY(disks.at(0).eligible());
        QCOMPARE(disks.at(1).reason, "In use by the running system");
        QCOMPARE(disks.at(2).reason, "Smaller than 16 GiB");
        QCOMPARE(disks.at(3).reason, "Reports no serial number");
        QCOMPARE(disks.at(4).reason, "Read-only");
    }

    void resolvesOnlyAnEligibleUniqueDisk()
    {
        QList<Disk> disks = parseDisks(lsblk);
        QCOMPARE(resolveDisk(disks, "wwn-eui.01").path, "/dev/nvme0n1");
        QCOMPARE(code([&] { resolveDisk(disks, "wwn-missing"); }), "disk-not-found");
        QCOMPARE(code([&] { resolveDisk(disks, ""); }), "disk-not-found");
        QCOMPARE(code([&] { resolveDisk(disks, "serial-S2"); }), "disk-not-eligible");
        disks.append(disks.first());
        QCOMPARE(code([&] { resolveDisk(disks, "wwn-eui.01"); }), "disk-ambiguous");
    }

    void validatesPlans()
    {
        const QList<Disk> disks = parseDisks(lsblk);
        const auto validate = [&](const QVariantMap &plan) { return code([&] { Installer::validatePlan(plan, disks); }); };
        QCOMPARE(validate({{"disk", "wwn-eui.01"}, {"userName", "dev"}}), "ok");
        QCOMPARE(validate({{"disk", "wwn-eui.01"}, {"userName", "dev"}, {"realName", "Dev Eloper"}}), "ok");
        QCOMPARE(validate({{"disk", "serial-S3"}, {"userName", "dev"}}), "disk-not-eligible");
        for (const char *name : {"", "root", "Dev", "1dev", "dev user", "dev;reboot"})
            QCOMPARE(validate({{"disk", "wwn-eui.01"}, {"userName", name}}), "invalid-user-name");
        QCOMPARE(validate({{"disk", "wwn-eui.01"}, {"userName", "dev"}, {"realName", "a:b"}}), "invalid-real-name");

        const Plan plan = Installer::validatePlan({{"disk", "wwn-eui.01"}, {"userName", "dev"}}, disks);
        QCOMPARE(plan.realName, "dev");
        QCOMPARE(plan.diskSize, 512110190592);
    }

    void validatesSettings()
    {
        const QList<Disk> disks = parseDisks(lsblk);
        const auto validate = [&](const QString &key, const QString &value) {
            return code([&] { Installer::validatePlan({{"disk", "wwn-eui.01"}, {"userName", "dev"}, {key, value}}, disks); });
        };
        QCOMPARE(validate("locale", "pl_PL.UTF-8"), "ok");
        QCOMPARE(validate("keyboardLayout", "us(dvorak)"), "ok");
        QCOMPARE(validate("timeZone", "America/Argentina/Buenos_Aires"), "ok");
        // Each ends up in a file or a path in /etc.
        QCOMPARE(validate("locale", "en_US\nLC_ALL=x"), "invalid-setting");
        QCOMPARE(validate("keyboardLayout", "us\nKEYMAP=x"), "invalid-setting");
        QCOMPARE(validate("timeZone", "../../etc/shadow"), "invalid-setting");
        QCOMPARE(validate("timeZone", "/etc/shadow"), "invalid-setting");
    }

    void connectsToNetworks()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        const auto connected = [&] {
            for (const QVariantMap &network : installer.ListNetworks()) {
                if (network.value("connected").toBool())
                    return network.value("ssid").toString();
            }
            return QString();
        };
        installer.ConnectNetwork("Simulated Home"); // Needs a password.
        QCOMPARE(connected(), "");
        sendSecret(installer, "wifi-password", "wrong");
        installer.ConnectNetwork("Simulated Home");
        QCOMPARE(connected(), "");
        sendSecret(installer, "wifi-password", "right");
        installer.ConnectNetwork("Simulated Home");
        QCOMPARE(connected(), "Simulated Home");
        installer.ConnectNetwork("Simulated Café"); // Open.
        QCOMPARE(connected(), "Simulated Café");
    }

    void aWifiPasswordIsNotAnOwnerPassword()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        sendSecret(installer, "wifi-password", "secret");
        installer.Install(goodDisk);
        QCOMPARE(installer.phase(), Phase::idle);
    }

    void installsWithPasswordFromPipe()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        sendPassword(installer, "secret");
        installer.Install(goodDisk);
        QTRY_COMPARE(installer.phase(), Phase::awaitingAcknowledgement);

        QDBusUnixFileDescriptor key = installer.TakeRecoveryKey();
        QFile pipe;
        QVERIFY(pipe.open(key.fileDescriptor(), QIODevice::ReadOnly));
        QVERIFY(pipe.readAll().startsWith("simulated-recovery-key"));

        installer.Reboot(); // Refused: not acknowledged yet.
        QCOMPARE(installer.phase(), Phase::awaitingAcknowledgement);
        installer.Acknowledge();
        QCOMPARE(installer.phase(), Phase::completed);
        QVERIFY(!installer.TakeRecoveryKey().isValid());
    }

    void refusesToInstallWithoutPassword()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        installer.Install(goodDisk);
        QCOMPARE(installer.phase(), Phase::idle);

        // A pipe that is still open has not delivered the whole password.
        QDBusUnixFileDescriptor open = installer.OpenSecret("owner-password");
        QCOMPARE(::write(open.fileDescriptor(), "half", 4), 4);
        installer.Install(goodDisk);
        QCOMPARE(installer.phase(), Phase::idle);
    }

    void refusesUnusablePasswords()
    {
        for (const QByteArray &password : {QByteArray(), QByteArray("two\nlines"), QByteArray(600, 'x')}) {
            SimulatedEngine engine;
            Installer installer(&engine);
            installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
            sendPassword(installer, password);
            installer.Install(goodDisk);
            QCOMPARE(installer.phase(), Phase::idle);
        }
    }

    void refusesADiskThatWasNotPlanned()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        sendPassword(installer, "secret");
        installer.Install("serial-SIM0002");
        QCOMPARE(installer.phase(), Phase::idle);
    }

    void aNewPlanDiscardsThePassword()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        sendPassword(installer, "secret");
        installer.SetPlan({{"disk", goodDisk}, {"userName", "other"}});
        installer.Install(goodDisk);
        QCOMPARE(installer.phase(), Phase::idle);
    }

    void reportsFailureAndAllowsANewPlan()
    {
        SimulatedEngine engine;
        Installer installer(&engine);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "fail"}});
        sendPassword(installer, "secret");
        installer.Install(goodDisk);
        QTRY_COMPARE(installer.phase(), Phase::failed);
        installer.SetPlan({{"disk", goodDisk}, {"userName", "dev"}});
        QCOMPARE(installer.phase(), Phase::idle);
    }

private:
    // Writes the secret and closes the pipe, as a frontend does.
    static void sendSecret(Installer &installer, const QString &kind, const QByteArray &secret)
    {
        QDBusUnixFileDescriptor pipe = installer.OpenSecret(kind);
        QVERIFY(pipe.isValid());
        QCOMPARE(::write(pipe.fileDescriptor(), secret.constData(), secret.size()), secret.size());
    }
    static void sendPassword(Installer &installer, const QByteArray &password)
    {
        sendSecret(installer, "owner-password", password);
    }
};

QTEST_GUILESS_MAIN(BackendTest)
#include "tst_backend.moc"
