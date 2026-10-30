// Disk discovery. A disk is identified by its WWN or serial number, never by
// its device name, which can change as storage is attached or rediscovered.
#pragma once

#include <QByteArray>
#include <QList>
#include <QString>
#include <QVariantMap>

struct Disk {
    QString id; // Empty if the disk reports neither a WWN nor a serial number.
    QString path;
    QString model;
    QString transport;
    qint64 size = 0;
    bool removable = false;
    QString reason; // Why the disk cannot be a target; empty if it can.

    bool eligible() const { return reason.isEmpty(); }
    QVariantMap toMap() const;
};

// The smallest disk the system fits on.
inline constexpr qint64 minimumDiskSize = 16LL * 1024 * 1024 * 1024;

// Parses `lsblk --json --bytes --output NAME,PATH,TYPE,SIZE,MODEL,SERIAL,WWN,TRAN,RO,RM,MOUNTPOINTS`.
QList<Disk> parseDisks(const QByteArray &lsblkJson);

// The disks of this machine. Throws Failure if lsblk fails.
QList<Disk> listDisks();

// The eligible disk with this id. Throws Failure if there is none, or more than one.
Disk resolveDisk(const QList<Disk> &disks, const QString &id);
