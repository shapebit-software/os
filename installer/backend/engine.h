// What the D-Bus object needs from the machine. SystemEngine works on real
// disks; SimulatedEngine fakes them for UI development and tests.
#pragma once

#include "disks.h"

#include <QObject>

struct Plan {
    QString disk; // Disk::id
    qint64 diskSize = 0; // As reviewed; a different size is a different disk.
    QString userName;
    QString realName;
    quint64 homeSize = 0; // 0: systemd-homed's default.
    // Settings of the installed system; empty leaves the image's default.
    QString locale;
    QString keyboardLayout; // XKB layout, with its variant in parentheses.
    QString timeZone;
};

class Engine : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    virtual QVariantMap capabilities() = 0;
    virtual QList<Disk> disks() = 0;
    // Wi-Fi networks in range: ssid, strength, security, connected.
    virtual QList<QVariantMap> networks() = 0;
    // Returns once connected. Throws Failure.
    virtual void connectNetwork(const QString &ssid, const QByteArray &password) = 0;
    // Starts the installation and returns; progress arrives as signals.
    virtual void install(const Plan &plan, const QByteArray &password) = 0;
    // Stops an installation that has not yet touched the disk.
    virtual void cancel() = 0;
    virtual void reboot() = 0;

signals:
    void phaseChanged(const QString &phase);
    void failed(const QString &code, const QString &message);
    void finished(const QByteArray &recoveryKey);
};
