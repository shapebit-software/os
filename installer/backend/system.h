// The real engine: installs to a disk of this machine. The steps run in a
// worker thread, one tool after another, so the D-Bus object stays responsive.
#pragma once

#include "engine.h"

#include <atomic>

class SystemEngine : public Engine
{
    Q_OBJECT
public:
    using Engine::Engine;

    QVariantMap capabilities() override;
    QList<Disk> disks() override { return listDisks(); }
    // Wi-Fi is not implemented yet: no networks, so the frontend offers none.
    QList<QVariantMap> networks() override { return {}; }
    void connectNetwork(const QString &ssid, const QByteArray &password) override;
    void install(const Plan &plan, const QByteArray &password) override;
    void cancel() override { m_cancelled = true; }
    void reboot() override;

private:
    std::atomic_bool m_cancelled = false;
};
