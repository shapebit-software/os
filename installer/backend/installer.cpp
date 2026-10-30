#include "installer.h"

#include "command.h"
#include "names.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QRegularExpression>
#include <QTimer>

#include <sys/socket.h>
#include <unistd.h>

namespace {

constexpr qsizetype maximumPasswordSize = 512;
constexpr int secretLifetimeMs = 60 * 1000;

// A connected pair of sockets, used as a one-way pipe: SELinux lets the bus
// pass a service's sockets to its clients, but not its pipes. Both ends close
// on exec, so no tool the backend runs inherits them.
bool openPipe(int fds[2])
{
    return ::socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0, fds) == 0;
}

} // namespace

Installer::Installer(Engine *engine, QObject *parent)
    : QObject(parent), m_engine(engine), m_phase(Phase::idle)
{
    connect(engine, &Engine::phaseChanged, this, &Installer::setPhase);
    connect(engine, &Engine::failed, this, [this](const QString &code, const QString &message) {
        setPhase(Phase::failed);
        emit Failed(code, message);
    });
    connect(engine, &Engine::finished, this, [this](const QByteArray &recoveryKey) {
        m_recoveryKey = recoveryKey;
        setPhase(Phase::awaitingAcknowledgement);
    });
}

Installer::~Installer()
{
    closeSecret();
    wipe(m_recoveryKey);
}

Plan Installer::validatePlan(const QVariantMap &plan, const QList<Disk> &disks)
{
    static const QRegularExpression userName(QStringLiteral("^[a-z][a-z0-9_-]{0,30}$"));
    static const QRegularExpression control(QStringLiteral("[\\x00-\\x1f\\x7f:]"));

    Plan result;
    const Disk disk = resolveDisk(disks, plan.value(QStringLiteral("disk")).toString());
    result.disk = disk.id;
    result.diskSize = disk.size;
    result.userName = plan.value(QStringLiteral("userName")).toString();
    if (!userName.match(result.userName).hasMatch() || result.userName == QLatin1String("root"))
        throw Failure{QStringLiteral("invalid-user-name"),
                      QStringLiteral("The user name must start with a letter and use only a-z, 0-9, - and _")};
    result.realName = plan.value(QStringLiteral("realName"), result.userName).toString();
    if (result.realName.isEmpty() || result.realName.size() > 100 || control.match(result.realName).hasMatch())
        throw Failure{QStringLiteral("invalid-real-name"), QStringLiteral("The name is empty, too long, or has unusable characters")};
    result.homeSize = plan.value(QStringLiteral("homeSize")).toULongLong();

    // These become file contents and a path in the installed system's /etc.
    static const QRegularExpression locale(QStringLiteral("^[A-Za-z]{1,8}(_[A-Za-z]{2,4})?(\\.[A-Za-z0-9-]{1,16})?(@[A-Za-z0-9]{1,16})?$"));
    static const QRegularExpression layout(QStringLiteral("^[a-z0-9_]{1,32}(\\([a-z0-9_-]{1,32}\\))?$"));
    static const QRegularExpression timeZone(QStringLiteral("^[A-Za-z0-9_+-]{1,32}(/[A-Za-z0-9_+-]{1,32}){0,2}$"));
    const auto setting = [&plan](const QString &key, const QRegularExpression &allowed) {
        const QString value = plan.value(key).toString();
        if (!value.isEmpty() && !allowed.match(value).hasMatch())
            throw Failure{QStringLiteral("invalid-setting"), QStringLiteral("%1 has an unusable value").arg(key)};
        return value;
    };
    result.locale = setting(QStringLiteral("locale"), locale);
    result.keyboardLayout = setting(QStringLiteral("keyboardLayout"), layout);
    result.timeZone = setting(QStringLiteral("timeZone"), timeZone);
    return result;
}

QVariantMap Installer::GetCapabilities()
{
    return m_engine->capabilities();
}

QList<QVariantMap> Installer::ListDisks()
{
    QList<QVariantMap> result;
    try {
        for (const Disk &disk : m_engine->disks())
            result.append(disk.toMap());
    } catch (const Failure &failure) {
        reject(failure.code, failure.message);
    }
    return result;
}

QList<QVariantMap> Installer::ListNetworks()
{
    return m_engine->networks();
}

void Installer::ConnectNetwork(const QString &ssid)
{
    if (!requirePhase({Phase::idle}))
        return;
    // An open network needs no password, so none may have been sent.
    const bool secured = m_secretKind == QLatin1String("wifi-password");
    if (secured && !readSecret(m_secretKind)) {
        closeSecret();
        reject(QStringLiteral("no-password"), QStringLiteral("The Wi-Fi password was not received"));
        return;
    }
    try {
        m_engine->connectNetwork(ssid, secured ? m_incoming : QByteArray());
    } catch (const Failure &failure) {
        reject(failure.code, failure.message);
    }
    if (secured)
        closeSecret();
}

void Installer::SetPlan(const QVariantMap &plan)
{
    if (!requirePhase({Phase::idle, Phase::failed}))
        return;
    closeSecret();
    m_planned = false;
    try {
        m_plan = validatePlan(plan, m_engine->disks());
        m_planned = true;
        setPhase(Phase::idle);
    } catch (const Failure &failure) {
        reject(failure.code, failure.message);
    }
}

QDBusUnixFileDescriptor Installer::OpenSecret(const QString &kind)
{
    if (!requirePhase({Phase::idle}))
        return {};
    if (kind != QLatin1String("owner-password") && kind != QLatin1String("wifi-password")) {
        reject(QStringLiteral("unknown-secret"), QStringLiteral("Unknown secret kind"));
        return {};
    }
    closeSecret();
    int fds[2];
    if (!openPipe(fds)) {
        reject(QStringLiteral("internal"), QStringLiteral("Could not create a pipe"));
        return {};
    }
    m_secretFd = fds[0];
    m_secretKind = kind;
    m_incoming.reserve(maximumPasswordSize + 256); // No reallocation leaves copies behind.
    QDBusUnixFileDescriptor writeEnd(fds[1]); // Duplicates the descriptor.
    ::close(fds[1]);
    // An unused channel does not stay open.
    const int fd = m_secretFd;
    QTimer::singleShot(secretLifetimeMs, this, [this, fd] {
        if (m_secretFd == fd && m_phase == Phase::idle)
            closeSecret();
    });
    return writeEnd;
}

bool Installer::readSecret(const QString &kind)
{
    const auto usable = [this, &kind] {
        return m_secretKind == kind && m_secretComplete && !m_incoming.isEmpty()
            && m_incoming.size() <= maximumPasswordSize && !m_incoming.contains('\n') && !m_incoming.contains('\0');
    };
    if (m_secretFd < 0 || m_secretComplete)
        return usable();
    char buffer[256];
    for (;;) {
        const ssize_t count = ::read(m_secretFd, buffer, sizeof buffer);
        if (count > 0) {
            m_incoming.append(buffer, count);
            explicit_bzero(buffer, sizeof buffer);
            if (m_incoming.size() > maximumPasswordSize)
                break;
        } else {
            // End of file: the frontend closed its end, so the secret is whole.
            m_secretComplete = count == 0;
            break;
        }
    }
    ::close(m_secretFd);
    m_secretFd = -1;
    return usable();
}

void Installer::closeSecret()
{
    if (m_secretFd >= 0)
        ::close(m_secretFd);
    m_secretFd = -1;
    m_secretKind.clear();
    m_secretComplete = false;
    wipe(m_incoming);
}

void Installer::Install(const QString &diskId)
{
    if (!requirePhase({Phase::idle}))
        return;
    if (!m_planned || diskId != m_plan.disk) {
        reject(QStringLiteral("not-confirmed"), QStringLiteral("The confirmed disk is not the planned disk"));
        return;
    }
    if (!readSecret(QStringLiteral("owner-password"))) {
        closeSecret();
        reject(QStringLiteral("no-password"), QStringLiteral("The owner password was not received"));
        return;
    }
    setPhase(Phase::validating);
    m_engine->install(m_plan, m_incoming);
    closeSecret();
    m_planned = false;
}

void Installer::Cancel()
{
    if (requirePhase({Phase::validating, Phase::preparing}))
        m_engine->cancel();
}

QDBusUnixFileDescriptor Installer::TakeRecoveryKey()
{
    if (!requirePhase({Phase::awaitingAcknowledgement}))
        return {};
    int fds[2];
    // The key is far smaller than a pipe buffer, so this write cannot block.
    if (!openPipe(fds) || ::write(fds[1], m_recoveryKey.constData(), m_recoveryKey.size()) != m_recoveryKey.size()) {
        reject(QStringLiteral("internal"), QStringLiteral("Could not create a pipe"));
        return {};
    }
    ::close(fds[1]);
    QDBusUnixFileDescriptor readEnd(fds[0]);
    ::close(fds[0]);
    return readEnd;
}

void Installer::Acknowledge()
{
    if (!requirePhase({Phase::awaitingAcknowledgement}))
        return;
    wipe(m_recoveryKey);
    setPhase(Phase::completed);
    emit Completed();
}

void Installer::Reboot()
{
    if (requirePhase({Phase::completed}))
        m_engine->reboot();
}

void Installer::setPhase(const QString &phase)
{
    if (m_phase == phase)
        return;
    m_phase = phase;
    emit PhaseChanged(phase);
}

void Installer::reject(const QString &code, const QString &message)
{
    // D-Bus error names allow no hyphens.
    if (calledFromDBus())
        sendErrorReply(Names::error + QString(code).replace(QLatin1Char('-'), QLatin1Char('_')), message);
}

bool Installer::requirePhase(std::initializer_list<QString> phases)
{
    for (const QString &phase : phases) {
        if (m_phase == phase)
            return true;
    }
    reject(QStringLiteral("wrong-phase"), QStringLiteral("Not possible while the phase is %1").arg(m_phase));
    return false;
}
