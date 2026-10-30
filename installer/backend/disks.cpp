#include "disks.h"

#include "command.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

// True if the device or anything on it is mounted or used as swap. This covers
// the disk the installer booted from.
bool inUse(const QJsonObject &device)
{
    for (const QJsonValue mountpoint : device.value(QLatin1String("mountpoints")).toArray()) {
        if (!mountpoint.isNull())
            return true;
    }
    for (const QJsonValue child : device.value(QLatin1String("children")).toArray()) {
        if (inUse(child.toObject()))
            return true;
    }
    return false;
}

QString text(const QJsonObject &device, QLatin1String key)
{
    return device.value(key).toString().simplified();
}

} // namespace

QVariantMap Disk::toMap() const
{
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("path"), path},
        {QStringLiteral("model"), model},
        {QStringLiteral("transport"), transport},
        {QStringLiteral("size"), size},
        {QStringLiteral("removable"), removable},
        {QStringLiteral("eligible"), eligible()},
        {QStringLiteral("reason"), reason},
    };
}

QList<Disk> parseDisks(const QByteArray &lsblkJson)
{
    QList<Disk> disks;
    const QJsonArray devices = QJsonDocument::fromJson(lsblkJson).object().value(QLatin1String("blockdevices")).toArray();
    for (const QJsonValue value : devices) {
        const QJsonObject device = value.toObject();
        // zram and other RAM-backed devices are also of type "disk".
        if (text(device, QLatin1String("type")) != QLatin1String("disk")
            || text(device, QLatin1String("name")).startsWith(QLatin1String("zram")))
            continue;

        Disk disk;
        disk.path = text(device, QLatin1String("path"));
        disk.model = text(device, QLatin1String("model"));
        disk.transport = text(device, QLatin1String("tran"));
        disk.size = device.value(QLatin1String("size")).toInteger();
        disk.removable = device.value(QLatin1String("rm")).toBool();

        const QString wwn = text(device, QLatin1String("wwn"));
        const QString serial = text(device, QLatin1String("serial"));
        if (!wwn.isEmpty())
            disk.id = QStringLiteral("wwn-") + wwn;
        else if (!serial.isEmpty())
            disk.id = QStringLiteral("serial-") + serial;

        if (inUse(device))
            disk.reason = QStringLiteral("In use by the running system");
        else if (device.value(QLatin1String("ro")).toBool())
            disk.reason = QStringLiteral("Read-only");
        else if (disk.id.isEmpty())
            disk.reason = QStringLiteral("Reports no serial number");
        else if (disk.size < minimumDiskSize)
            disk.reason = QStringLiteral("Smaller than 16 GiB");
        disks.append(disk);
    }
    return disks;
}

QList<Disk> listDisks()
{
    return parseDisks(run({QStringLiteral("lsblk"), QStringLiteral("--json"), QStringLiteral("--bytes"),
                           QStringLiteral("--output"),
                           QStringLiteral("NAME,PATH,TYPE,SIZE,MODEL,SERIAL,WWN,TRAN,RO,RM,MOUNTPOINTS")}));
}

Disk resolveDisk(const QList<Disk> &disks, const QString &id)
{
    QList<Disk> matches;
    for (const Disk &disk : disks) {
        if (!id.isEmpty() && disk.id == id)
            matches.append(disk);
    }
    if (matches.isEmpty())
        throw Failure{QStringLiteral("disk-not-found"), QStringLiteral("The selected disk is no longer attached")};
    if (matches.size() > 1)
        throw Failure{QStringLiteral("disk-ambiguous"), QStringLiteral("More than one disk has the selected identity")};
    if (!matches.first().eligible())
        throw Failure{QStringLiteral("disk-not-eligible"), matches.first().reason};
    return matches.first();
}
