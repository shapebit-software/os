// Names and types shared by both sides of installer.xml.
#pragma once

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QList>
#include <QString>
#include <QVariantMap>

namespace Names {
inline const QString service = QStringLiteral("software.shapebit.Installer1");
inline const QString path = QStringLiteral("/software/shapebit/Installer1");
inline const QString error = QStringLiteral("software.shapebit.Installer1.Error.");
}

namespace Phase {
inline const QString idle = QStringLiteral("idle");
inline const QString validating = QStringLiteral("validating");
inline const QString preparing = QStringLiteral("preparing");
inline const QString creatingStorage = QStringLiteral("creating-storage");
inline const QString installingSystem = QStringLiteral("installing-system");
inline const QString configuring = QStringLiteral("configuring");
inline const QString verifying = QStringLiteral("verifying");
inline const QString awaitingAcknowledgement = QStringLiteral("awaiting-acknowledgement");
inline const QString completed = QStringLiteral("completed");
inline const QString failed = QStringLiteral("failed");
}

// ListDisks returns aa{sv}, which Qt does not register by default.
inline void registerTypes()
{
    qDBusRegisterMetaType<QList<QVariantMap>>();
}

// The real backend is on the system bus; the simulated one on the session bus.
inline QDBusConnection installerBus(bool session)
{
    return session ? QDBusConnection::sessionBus() : QDBusConnection::systemBus();
}
