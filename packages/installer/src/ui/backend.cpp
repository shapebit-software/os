#include "backend.h"

#include "names.h"

#include <QFile>
#include <QLocale>

#include <unistd.h>

Backend::Backend(QObject *parent)
    : QObject(parent), m_installer(Names::service, Names::path, installerBus(session))
{
    m_installer.setTimeout(30 * 1000);
    connect(&m_installer, &software::shapebit::Installer1::PhaseChanged, this, &Backend::setPhase);
    connect(&m_installer, &software::shapebit::Installer1::Failed, this,
            [this](const QString &, const QString &message) { setError(message); });
    refresh();
}

template <typename Reply>
bool Backend::check(Reply &reply)
{
    reply.waitForFinished();
    if (reply.isError())
        setError(reply.error().message());
    return !reply.isError();
}

void Backend::refresh()
{
    auto capabilities = m_installer.GetCapabilities();
    auto disks = m_installer.ListDisks();
    m_available = check(capabilities) && check(disks);
    m_capabilities = capabilities.value();
    m_disks.clear();
    for (const QVariantMap &disk : disks.value())
        m_disks.append(disk);
    if (m_available) {
        setError({});
        setPhase(m_installer.phase());
    }
    emit changed();
}

void Backend::refreshNetworks()
{
    auto networks = m_installer.ListNetworks();
    networks.waitForFinished();
    m_networks.clear();
    for (const QVariantMap &network : networks.value())
        m_networks.append(network);
    emit networksChanged();
}

bool Backend::connectNetwork(const QString &ssid, const QString &password)
{
    setError({});
    if (!password.isEmpty() && !sendSecret(QStringLiteral("wifi-password"), password))
        return false;
    auto connected = m_installer.ConnectNetwork(ssid);
    const bool ok = check(connected);
    refreshNetworks();
    return ok;
}

QString Backend::languageName(const QString &locale)
{
    const QLocale language(locale);
    QString name = language.nativeLanguageName();
    if (!name.isEmpty())
        name[0] = name.at(0).toUpper();
    return QStringLiteral("%1 (%2)").arg(name, QLocale::territoryToCode(language.territory()));
}

bool Backend::sendSecret(const QString &kind, const QString &text)
{
    auto secret = m_installer.OpenSecret(kind);
    if (!check(secret))
        return false;
    QByteArray bytes = text.toUtf8();
    QFile pipe;
    const bool sent = pipe.open(::dup(secret.value().fileDescriptor()), QIODevice::WriteOnly, QFileDevice::AutoCloseHandle)
        && pipe.write(bytes) == bytes.size();
    explicit_bzero(bytes.data(), bytes.size());
    if (!sent)
        setError(tr("The password could not be sent."));
    // The reply holds the other copy of the write end, and the backend sees
    // the end of the secret only when both are closed: the reply's with this
    // function's return, the pipe's just before.
    return sent;
}

bool Backend::install(const QVariantMap &plan, const QString &password)
{
    setError({});
    auto planned = m_installer.SetPlan(plan);
    if (!check(planned))
        return false;
    if (!sendSecret(QStringLiteral("owner-password"), password))
        return false;
    auto started = m_installer.Install(plan.value(QStringLiteral("disk")).toString());
    return check(started);
}

void Backend::cancel()
{
    auto reply = m_installer.Cancel();
    check(reply);
}

QString Backend::takeRecoveryKey()
{
    auto reply = m_installer.TakeRecoveryKey();
    QFile pipe;
    if (!check(reply) || !pipe.open(::dup(reply.value().fileDescriptor()), QIODevice::ReadOnly, QFileDevice::AutoCloseHandle))
        return {};
    return QString::fromUtf8(pipe.readAll());
}

void Backend::acknowledge()
{
    auto reply = m_installer.Acknowledge();
    check(reply);
}

void Backend::reboot()
{
    auto reply = m_installer.Reboot();
    check(reply);
}

void Backend::setPhase(const QString &phase)
{
    if (m_phase == phase)
        return;
    m_phase = phase;
    emit phaseChanged();
}

void Backend::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}
