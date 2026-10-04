#include "system.h"

#include "command.h"
#include "names.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QSettings>
#include <QThread>

namespace {

// Written when the installer medium is built: what to install and where the
// installed system updates from.
const QString configuration = QStringLiteral("/usr/share/installer/installer.conf");
// Copied into the installed system's /etc, if present.
const QString targetEtc = QStringLiteral("/usr/share/installer/target-etc");
// Signs the PCR 11 values that every ShapeBit UKI carries; from the booted UKI.
const QString pcrPublicKey = QStringLiteral("/run/systemd/tpm2-pcr-public-key.pem");

const QString consoleKeymaps = QStringLiteral("/usr/lib/kbd/keymaps/xkb/");
const QString zoneInfo = QStringLiteral("/usr/share/zoneinfo/");

const QString work = QStringLiteral("/run/installer");
const QString installKey = work + QStringLiteral("/key");
const QString top = work + QStringLiteral("/top");
const QString target = work + QStringLiteral("/target");
const QString mapperName = QStringLiteral("install-root");
const QString mapper = QStringLiteral("/dev/mapper/") + mapperName;
const QString machineIdFile = work + QStringLiteral("/machine-id");
const QString homedState = QStringLiteral("/var/lib/systemd/home");
const QString homes = QStringLiteral("/var/home");
// A runtime drop-in that points this system's systemd-homed at the target.
const QString homedDropIn = QStringLiteral("/run/systemd/system/systemd-homed.service.d/50-installer.conf");

// True if the EFI variable's value, after its 4 attribute bytes, is 1.
bool efiFlag(const QString &name)
{
    QFile file(QStringLiteral("/sys/firmware/efi/efivars/%1-8be4df61-93ca-11d2-aa0d-00e098032b8c").arg(name));
    return file.open(QIODevice::ReadOnly) && file.readAll().mid(4, 1) == QByteArray(1, '\1');
}

void write(const QString &path, const QByteArray &content, QIODevice::OpenMode mode = QIODevice::WriteOnly)
{
    QFile file(path);
    if (!file.open(mode) || file.write(content) != content.size())
        throw Failure{QStringLiteral("write-failed"), QStringLiteral("Could not write %1").arg(path)};
}

class Installation
{
public:
    Installation(SystemEngine *engine, const std::atomic_bool &cancelled, const Plan &plan, const QByteArray &password)
        : m_engine(engine), m_cancelled(cancelled), m_plan(plan), m_password(password) {}

    void perform()
    {
        try {
            emit m_engine->phaseChanged(Phase::validating);
            validate();
            emit m_engine->phaseChanged(Phase::preparing);
            prepare();
            // The last moment before the disk changes: Cancel still applies,
            // and the reviewed identity must still name the same device.
            if (m_cancelled)
                throw Failure{QStringLiteral("cancelled"), QStringLiteral("The installation was cancelled")};
            resolve();
            emit m_engine->phaseChanged(Phase::creatingStorage);
            createStorage();
            emit m_engine->phaseChanged(Phase::installingSystem);
            installSystem();
            emit m_engine->phaseChanged(Phase::configuring);
            configure();
            emit m_engine->phaseChanged(Phase::verifying);
            verify();
            cleanUp();
            emit m_engine->finished(m_recoveryKey);
        } catch (const Failure &failure) {
            cleanUp();
            emit m_engine->failed(failure.code, failure.message);
        }
        wipe(m_password);
        wipe(m_recoveryKey);
    }

private:
    void resolve()
    {
        const Disk disk = resolveDisk(listDisks(), m_plan.disk);
        if (disk.size != m_plan.diskSize)
            throw Failure{QStringLiteral("disk-changed"), QStringLiteral("The selected disk changed since it was reviewed")};
        m_disk = disk.path;
    }

    void validate()
    {
        const QVariantMap capabilities = m_engine->capabilities();
        if (!capabilities.value(QStringLiteral("uefi")).toBool())
            throw Failure{QStringLiteral("no-uefi"), QStringLiteral("This machine did not start in UEFI mode")};
        if (!capabilities.value(QStringLiteral("tpm2")).toBool() || !QFile::exists(pcrPublicKey))
            throw Failure{QStringLiteral("no-tpm2"), QStringLiteral("This machine has no usable TPM 2.0")};
        resolve();

        const QSettings settings(configuration, QSettings::IniFormat);
        m_source = settings.value(QStringLiteral("Payload/Source")).toString();
        m_updateRef = settings.value(QStringLiteral("Payload/UpdateRef")).toString();
        if (m_source.isEmpty() || m_updateRef.isEmpty())
            throw Failure{QStringLiteral("no-payload"), QStringLiteral("%1 names no system to install").arg(configuration)};
        // The medium carries the system it installs, so its zones are the target's.
        if (!m_plan.timeZone.isEmpty() && !QFile::exists(zoneInfo + m_plan.timeZone))
            throw Failure{QStringLiteral("invalid-setting"), QStringLiteral("Unknown time zone")};
    }

    void prepare()
    {
        // A random installation key opens the volume during the install; the
        // TPM and the recovery key replace it. /run is memory, never the disk.
        QDir().mkpath(top);
        QDir().mkpath(target);
        QByteArray key(64, Qt::Uninitialized);
        QRandomGenerator::system()->generate(key.begin(), key.end());
        QFile::remove(installKey);
        QFile file(installKey);
        if (!file.open(QIODevice::WriteOnly | QIODevice::NewOnly, QFileDevice::ReadOwner | QFileDevice::WriteOwner)
            || file.write(key) != key.size())
            throw Failure{QStringLiteral("write-failed"), QStringLiteral("Could not write the installation key")};
        wipe(key);
    }

    void createStorage()
    {
        // GPT: EFI System Partition and the LUKS2 volume, typed as the x86-64
        // root partition so that systemd finds and unlocks it by itself.
        run({QStringLiteral("sfdisk"), QStringLiteral("--quiet"), QStringLiteral("--wipe"), QStringLiteral("always"),
             QStringLiteral("--wipe-partitions"), QStringLiteral("always"), QStringLiteral("--label"), QStringLiteral("gpt"), m_disk},
            "size=1GiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=esp\n"
            "           type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name=shapebit\n");
        run({QStringLiteral("udevadm"), QStringLiteral("settle")});
        // The kernel puts "p" before the partition number if the disk name ends in a digit.
        const QString prefix = m_disk.back().isDigit() ? m_disk + QLatin1Char('p') : m_disk;
        m_esp = prefix + QLatin1Char('1');
        m_luks = prefix + QLatin1Char('2');

        run({QStringLiteral("mkfs.vfat"), QStringLiteral("-F"), QStringLiteral("32"), QStringLiteral("-n"), QStringLiteral("ESP"), m_esp});
        run({QStringLiteral("cryptsetup"), QStringLiteral("luksFormat"), QStringLiteral("--batch-mode"), QStringLiteral("--type"),
             QStringLiteral("luks2"), QStringLiteral("--label"), QStringLiteral("shapebit"), QStringLiteral("--key-file"), installKey, m_luks});
        run({QStringLiteral("cryptsetup"), QStringLiteral("open"), QStringLiteral("--key-file"), installKey, m_luks, mapperName});
        run({QStringLiteral("mkfs.btrfs"), QStringLiteral("-q"), QStringLiteral("-L"), QStringLiteral("shapebit"), mapper});

        run({QStringLiteral("mount"), mapper, top});
        for (const char *subvolume : {"@base", "@machine", "@people", "@recovery"})
            run({QStringLiteral("btrfs"), QStringLiteral("-q"), QStringLiteral("subvolume"), QStringLiteral("create"),
                 top + QLatin1Char('/') + QLatin1String(subvolume)});
        run({QStringLiteral("mount"), QStringLiteral("-o"), QStringLiteral("subvol=@base"), mapper, target});
        QDir().mkpath(target + QStringLiteral("/boot"));
        run({QStringLiteral("mount"), m_esp, target + QStringLiteral("/boot")});
    }

    void installSystem()
    {
        run({QStringLiteral("bootc"), QStringLiteral("install"), QStringLiteral("to-filesystem"),
             QStringLiteral("--composefs-backend"), QStringLiteral("--bootloader"), QStringLiteral("systemd"),
             QStringLiteral("--generic-image"), QStringLiteral("--skip-finalize"),
             QStringLiteral("--source-imgref"), m_source, QStringLiteral("--target-imgref"), m_updateRef,
             QStringLiteral("--skip-fetch-check"), target});

        // @machine holds /var and @people holds /home (/var/home). bootc filled
        // the stateroot's /var; move it into @machine, then mount both from
        // the deployment's /etc/fstab.
        const QString stateroot = target + QStringLiteral("/state/os/default/var");
        run({QStringLiteral("cp"), QStringLiteral("-a"), stateroot + QStringLiteral("/."), top + QStringLiteral("/@machine/")});
        run({QStringLiteral("find"), stateroot, QStringLiteral("-mindepth"), QStringLiteral("1"), QStringLiteral("-delete")});

        const QDir deployments(target + QStringLiteral("/state/deploy"));
        const QStringList names = deployments.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        if (names.size() != 1)
            throw Failure{QStringLiteral("no-deployment"), QStringLiteral("Expected one installed deployment")};
        const QString etc = deployments.filePath(names.first()) + QStringLiteral("/etc");
        const QString uuid = QString::fromUtf8(run({QStringLiteral("blkid"), QStringLiteral("-s"), QStringLiteral("UUID"),
                                                    QStringLiteral("-o"), QStringLiteral("value"), mapper})).trimmed();
        write(etc + QStringLiteral("/fstab"),
              QStringLiteral("UUID=%1 /var      btrfs subvol=@machine 0 0\n"
                             "UUID=%1 /var/home btrfs subvol=@people  0 0\n").arg(uuid).toUtf8(),
              QIODevice::Append);
        // The machine gets its ID now, not on its first boot: systemd-homed
        // binds the first owner's record to it (see createOwner).
        m_machineId = run({QStringLiteral("systemd-id128"), QStringLiteral("new")}).trimmed();
        write(etc + QStringLiteral("/machine-id"), m_machineId + '\n');
        writeSettings(etc);
        // Without -a, the copies get the labels of /etc, not of /usr/share.
        if (QDir(targetEtc).exists())
            run({QStringLiteral("cp"), QStringLiteral("-r"), targetEtc + QStringLiteral("/."), etc + QLatin1Char('/')});

        for (const QString &mountpoint : {target + QStringLiteral("/boot"), target})
            run({QStringLiteral("fstrim"), QStringLiteral("--quiet-unsupported"), mountpoint});
    }

    // The locale, keyboard layout, and time zone the user chose, in the files
    // systemd reads them from. validatePlan() restricted their characters.
    void writeSettings(const QString &etc)
    {
        if (!m_plan.locale.isEmpty())
            write(etc + QStringLiteral("/locale.conf"), "LANG=" + m_plan.locale.toUtf8() + '\n');
        if (!m_plan.keyboardLayout.isEmpty()) {
            // systemd-localed keeps the XKB layout here too.
            const QString layout = m_plan.keyboardLayout.section(QLatin1Char('('), 0, 0);
            const QString variant = m_plan.keyboardLayout.section(QLatin1Char('('), 1).remove(QLatin1Char(')'));
            QByteArray content = "XKBLAYOUT=" + layout.toUtf8() + '\n';
            if (!variant.isEmpty())
                content += "XKBVARIANT=" + variant.toUtf8() + '\n';
            // The console gets the same layout, so that the password typed
            // here signs in there: kbd ships console keymaps converted from
            // XKB, named "layout" or "layout-variant". The medium carries the
            // system it installs, so its keymaps are the target's.
            const QString keymap = variant.isEmpty() ? layout : layout + QLatin1Char('-') + variant;
            if (QFile::exists(consoleKeymaps + keymap + QStringLiteral(".map.gz")))
                content += "KEYMAP=" + keymap.toUtf8() + '\n';
            write(etc + QStringLiteral("/vconsole.conf"), content, QIODevice::Append);
        }
        if (!m_plan.timeZone.isEmpty()) {
            const QString link = etc + QStringLiteral("/localtime");
            QFile::remove(link);
            if (!QFile::link(QStringLiteral("..") + zoneInfo + m_plan.timeZone, link))
                throw Failure{QStringLiteral("write-failed"), QStringLiteral("Could not write %1").arg(link)};
        }
    }

    void configure()
    {
        m_recoveryKey = run({QStringLiteral("systemd-cryptenroll"), QStringLiteral("--unlock-key-file=") + installKey,
                             QStringLiteral("--recovery-key"), m_luks}).trimmed();
        // The TPM2 slot is bound to PCR 7 (the Secure Boot policy) and to
        // signed PCR 11 values (the UKI); it replaces the installation key.
        run({QStringLiteral("systemd-cryptenroll"), QStringLiteral("--unlock-key-file=") + installKey,
             QStringLiteral("--tpm2-device=auto"), QStringLiteral("--tpm2-pcrs=7"),
             QStringLiteral("--tpm2-public-key=") + pcrPublicKey, QStringLiteral("--tpm2-public-key-pcrs=11"),
             QStringLiteral("--wipe-slot=0"), m_luks});
        QFile::remove(installKey);
        createOwner();
    }

    // systemd-homed creates the first owner directly on the target. For the
    // duration, a drop-in gives this system's systemd-homed a private view:
    // the target's home storage, homed state, and machine ID in place of its
    // own. The home image, the user record, and the key that signs it land
    // where the installed system looks for them, and the record is bound to
    // the installed system's machine ID, so it is that system's own user.
    void createOwner()
    {
        const QString people = top + QStringLiteral("/@people");
        const QString state = top + QStringLiteral("/@machine/lib/systemd/home");
        QDir().mkpath(state);
        write(machineIdFile, m_machineId + '\n');
        // New files get their SELinux labels from these directories.
        run({QStringLiteral("chcon"), QStringLiteral("--reference=") + homes, people});
        run({QStringLiteral("chcon"), QStringLiteral("--reference=") + homedState, state});
        run({QStringLiteral("chcon"), QStringLiteral("--reference=/etc/machine-id"), machineIdFile});

        QDir().mkpath(QFileInfo(homedDropIn).path());
        write(homedDropIn, QStringLiteral("[Service]\n"
                                          "BindPaths=%1:%2 %3:%4\n"
                                          "BindReadOnlyPaths=%5:/etc/machine-id\n")
                               .arg(people, homes, state, homedState, machineIdFile).toUtf8());
        m_homedRedirected = true;
        restartHomed();

        QStringList create{QStringLiteral("homectl"), QStringLiteral("create"), m_plan.userName,
                           QStringLiteral("--real-name=") + m_plan.realName, QStringLiteral("--member-of=wheel")};
        if (m_plan.homeSize > 0)
            create.append(QStringLiteral("--disk-size=%1").arg(m_plan.homeSize));
        // homectl reads the new password from its environment, not its arguments.
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        environment.insert(QStringLiteral("NEWPASSWORD"), QString::fromUtf8(m_password));
        run(create, {}, environment);
        restoreHomed();
    }

    static void restartHomed()
    {
        run({QStringLiteral("systemctl"), QStringLiteral("daemon-reload")});
        run({QStringLiteral("systemctl"), QStringLiteral("restart"), QStringLiteral("systemd-homed.service")});
    }

    void restoreHomed()
    {
        if (!m_homedRedirected)
            return;
        m_homedRedirected = false;
        QFile::remove(homedDropIn);
        restartHomed();
    }

    void verify()
    {
        auto require = [](bool condition, const QString &what) {
            if (!condition)
                throw Failure{QStringLiteral("verification-failed"), QStringLiteral("Verification failed: %1").arg(what)};
        };

        const QJsonObject luks = QJsonDocument::fromJson(
            run({QStringLiteral("cryptsetup"), QStringLiteral("luksDump"), QStringLiteral("--dump-json-metadata"), m_luks})).object();
        QStringList tokens;
        for (const QJsonValue token : luks.value(QLatin1String("tokens")).toObject())
            tokens.append(token.toObject().value(QLatin1String("type")).toString());
        tokens.sort();
        require(tokens == QStringList{QStringLiteral("systemd-recovery"), QStringLiteral("systemd-tpm2")},
                QStringLiteral("the volume has exactly a TPM2 and a recovery token"));
        require(luks.value(QLatin1String("keyslots")).toObject().size() == 2,
                QStringLiteral("the volume has exactly two key slots"));
        // Both tests only try to unlock; they change no key slot.
        require(succeeds({QStringLiteral("cryptsetup"), QStringLiteral("open"), QStringLiteral("--test-passphrase"),
                          QStringLiteral("--key-file=-"), m_luks}, m_recoveryKey),
                QStringLiteral("the recovery key unlocks the volume"));
        require(succeeds({QStringLiteral("cryptsetup"), QStringLiteral("open"), QStringLiteral("--test-passphrase"),
                          QStringLiteral("--token-only"), QStringLiteral("--token-type"), QStringLiteral("systemd-tpm2"), m_luks}),
                QStringLiteral("the TPM unlocks the volume"));

        const QString boot = target + QStringLiteral("/boot");
        // bootc keeps its UKIs in a directory of their own below EFI/Linux.
        require(QDirIterator(boot + QStringLiteral("/EFI/Linux"), {QStringLiteral("*.efi")}, QDir::Files,
                             QDirIterator::Subdirectories).hasNext(),
                QStringLiteral("a UKI is on the EFI System Partition"));
        require(!QDir(boot + QStringLiteral("/loader/entries")).entryList({QStringLiteral("*.conf")}, QDir::Files).isEmpty(),
                QStringLiteral("a boot entry is on the EFI System Partition"));
        require(QFile::exists(boot + QStringLiteral("/EFI/BOOT/BOOTX64.EFI")),
                QStringLiteral("systemd-boot is on the EFI System Partition"));
        for (const char *subvolume : {"@base", "@machine", "@people", "@recovery"})
            require(succeeds({QStringLiteral("btrfs"), QStringLiteral("subvolume"), QStringLiteral("show"),
                              top + QLatin1Char('/') + QLatin1String(subvolume)}),
                    QStringLiteral("subvolume %1 exists").arg(QLatin1String(subvolume)));
        require(QFile::exists(top + QStringLiteral("/@people/%1.home").arg(m_plan.userName))
                    && QFile::exists(top + QStringLiteral("/@machine/lib/systemd/home/%1.identity").arg(m_plan.userName)),
                QStringLiteral("the first owner and their home exist"));
        run({QStringLiteral("sync")});
    }

    // Leaves nothing of the target mounted or unlocked, whether or not the
    // installation succeeded.
    void cleanUp()
    {
        try {
            restoreHomed();
        } catch (const Failure &) {
            // Best effort: the installation's own result is what gets reported.
        }
        QFile::remove(machineIdFile);
        QFile::remove(installKey);
        succeeds({QStringLiteral("umount"), QStringLiteral("-R"), target});
        succeeds({QStringLiteral("umount"), top});
        succeeds({QStringLiteral("cryptsetup"), QStringLiteral("close"), mapperName});
    }

    SystemEngine *m_engine;
    const std::atomic_bool &m_cancelled;
    Plan m_plan;
    QByteArray m_password;
    QByteArray m_recoveryKey;
    QByteArray m_machineId;
    QString m_source;
    QString m_updateRef;
    QString m_disk;
    QString m_esp;
    QString m_luks;
    bool m_homedRedirected = false;
};

} // namespace

QVariantMap SystemEngine::capabilities()
{
    QFile tpm(QStringLiteral("/sys/class/tpm/tpm0/tpm_version_major"));
    // The medium carries the system it installs, so its locales are the target's.
    QStringList locales;
    try {
        locales = QString::fromUtf8(run({QStringLiteral("localectl"), QStringLiteral("list-locales")}))
                      .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        // "C" is not a language to choose.
        locales.removeIf([](const QString &locale) { return locale.startsWith(QLatin1String("C.")); });
    } catch (const Failure &) {
        // No list: the frontend offers no choice and the image's default stays.
    }
    return {
        {QStringLiteral("uefi"), QDir(QStringLiteral("/sys/firmware/efi")).exists()},
        {QStringLiteral("secureBoot"), efiFlag(QStringLiteral("SecureBoot"))},
        {QStringLiteral("setupMode"), efiFlag(QStringLiteral("SetupMode"))},
        {QStringLiteral("tpm2"), tpm.open(QIODevice::ReadOnly) && tpm.readAll().trimmed() == "2"},
        {QStringLiteral("locales"), locales},
    };
}

void SystemEngine::connectNetwork(const QString &, const QByteArray &)
{
    throw Failure{QStringLiteral("not-supported"), QStringLiteral("Wi-Fi is not supported yet")};
}

void SystemEngine::install(const Plan &plan, const QByteArray &password)
{
    m_cancelled = false;
    // A deep copy: the caller wipes its own.
    const QByteArray secret(password.constData(), password.size());
    QThread *thread = QThread::create([this, plan, secret] {
        Installation(this, m_cancelled, plan, secret).perform();
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void SystemEngine::reboot()
{
    succeeds({QStringLiteral("systemctl"), QStringLiteral("reboot")});
}
