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

// What the machine always keeps in /var beside the homes, before metadata: the
// extras (desktop/extras), such as the assistant's and dictation's models,
// which need about 8 GB as they install, those added later, the journal, and
// caches
// (tests/unit/test_extra.py checks that the extras fit).
inline constexpr qint64 steadyRoom = 24LL * 1024 * 1024 * 1024;

// The reserve that the homes leave free on a file system of total bytes whose
// system uses system bytes (docs/Design-Base.md):
// max(64 GiB, steady + surge), where steady is steadyRoom plus 2% of the disk
// (between 4 and 16 GiB) for metadata, and surge is room for two more systems,
// at least 16 GiB: once a first update has run, the rollback's system stays
// beside the booted one, and the next update stages a third.
qint64 reserveSize(qint64 total, qint64 system);

// The first owner's home, unless the plan sets its size, on a file system of
// total bytes with available bytes free once the system is installed. The
// home takes the free space but for reserveSize(): systemd-homed claims the
// home's full size each time it opens it, and fails if the disk cannot hold it
// then. On a disk too small for the reserve, the home leaves as much again as
// the system uses, so that an update fits, and half of the rest. Throws
// Failure if less than a GiB would be left.
qint64 defaultHomeSize(qint64 total, qint64 available);

// Parses `lsblk --json --bytes --output NAME,PATH,TYPE,SIZE,MODEL,SERIAL,WWN,TRAN,RO,RM,MOUNTPOINTS`.
QList<Disk> parseDisks(const QByteArray &lsblkJson);

// The disks of this machine. Throws Failure if lsblk fails.
QList<Disk> listDisks();

// The eligible disk with this id. Throws Failure if there is none, or more than one.
Disk resolveDisk(const QList<Disk> &disks, const QString &id);
