// The backend as QML sees it: a singleton over the generated D-Bus proxy.
// Secrets pass through here on their way to and from one-shot pipes and are
// never logged.
#pragma once

#include "installerinterface.h"

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString phase READ phase NOTIFY phaseChanged)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY changed)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY changed)
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
public:
    explicit Backend(QObject *parent = nullptr);

    // Set by main() before QML starts: the simulated backend is on the session bus.
    static inline bool session = false;

    bool available() const { return m_available; }
    QString phase() const { return m_phase; }
    QVariantMap capabilities() const { return m_capabilities; }
    QVariantList disks() const { return m_disks; }
    QVariantList networks() const { return m_networks; }
    QString error() const { return m_error; }

    // Reads capabilities, disks, and the phase again.
    Q_INVOKABLE void refresh();
    // Looks for Wi-Fi networks again.
    Q_INVOKABLE void refreshNetworks();
    // Connects to a Wi-Fi network; the password is empty for an open one.
    // Returns false, with error set, if that fails.
    Q_INVOKABLE bool connectNetwork(const QString &ssid, const QString &password);
    // A locale's language in that language, for example "Deutsch (DE)".
    Q_INVOKABLE static QString languageName(const QString &locale);
    // Sends the plan and the password, then starts the installation of
    // plan.disk. This is the destructive confirmation. Returns false, with
    // error set, if the backend refuses.
    Q_INVOKABLE bool install(const QVariantMap &plan, const QString &password);
    Q_INVOKABLE void cancel();
    // The device recovery key; empty unless the phase is awaiting-acknowledgement.
    Q_INVOKABLE QString takeRecoveryKey();
    Q_INVOKABLE void acknowledge();
    Q_INVOKABLE void reboot();

signals:
    void changed();
    void phaseChanged();
    void networksChanged();
    void errorChanged();

private:
    template <typename Reply> bool check(Reply &reply);
    bool sendSecret(const QString &kind, const QString &secret);
    void setPhase(const QString &phase);
    void setError(const QString &error);

    software::shapebit::Installer1 m_installer;
    bool m_available = false;
    QString m_phase;
    QVariantMap m_capabilities;
    QVariantList m_disks;
    QVariantList m_networks;
    QString m_error;
};
