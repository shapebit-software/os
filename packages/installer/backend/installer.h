// The object exported on D-Bus (see interface/installer.xml). It validates
// requests, holds the secrets, and tracks the phase; an Engine does the work.
#pragma once

#include "engine.h"

#include <QDBusContext>
#include <QDBusUnixFileDescriptor>
#include <QObject>

class Installer : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_PROPERTY(QString Phase READ phase)
public:
    explicit Installer(Engine *engine, QObject *parent = nullptr);
    ~Installer() override;

    QString phase() const { return m_phase; }

    // Checks a plan from the frontend against the current disks. Throws Failure.
    static Plan validatePlan(const QVariantMap &plan, const QList<Disk> &disks);

public slots:
    QVariantMap GetCapabilities();
    QList<QVariantMap> ListDisks();
    QList<QVariantMap> ListNetworks();
    void ConnectNetwork(const QString &ssid);
    void SetPlan(const QVariantMap &plan);
    QDBusUnixFileDescriptor OpenSecret(const QString &kind);
    void Install(const QString &diskId);
    void Cancel();
    QDBusUnixFileDescriptor TakeRecoveryKey();
    void Acknowledge();
    void Reboot();

signals:
    void PhaseChanged(const QString &phase);
    void Failed(const QString &code, const QString &message);
    void Completed();

private:
    void setPhase(const QString &phase);
    void reject(const QString &code, const QString &message);
    bool requirePhase(std::initializer_list<QString> phases);
    // True if the secret of this kind arrived whole and is usable; it is then in m_incoming.
    bool readSecret(const QString &kind);
    void closeSecret();

    Engine *m_engine;
    QString m_phase;
    bool m_planned = false;
    Plan m_plan;
    int m_secretFd = -1; // Read end of the pipe from OpenSecret.
    QString m_secretKind;
    QByteArray m_incoming; // Secret bytes read so far.
    bool m_secretComplete = false;
    QByteArray m_recoveryKey;
};
