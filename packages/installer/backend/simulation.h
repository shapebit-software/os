// An engine that touches nothing: fake disks and timed phases, for developing
// and testing the frontend (`installer-backend --simulate`).
#pragma once

#include "engine.h"

#include <QTimer>

class SimulatedEngine : public Engine
{
    Q_OBJECT
public:
    explicit SimulatedEngine(QObject *parent = nullptr);

    QVariantMap capabilities() override;
    QList<Disk> disks() override;
    QList<QVariantMap> networks() override;
    void connectNetwork(const QString &ssid, const QByteArray &password) override;
    void install(const Plan &plan, const QByteArray &password) override;
    void cancel() override;
    void reboot() override;

private:
    void advance();

    QTimer m_timer;
    int m_step = 0;
    QString m_connected; // SSID
};
