// The time zones to choose from, from Qt's copy of the time zone database.
#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class TimeZones : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Each zone: id ("Europe/Berlin"), city, region, and offset ("UTC+2") as of now.
    Q_PROPERTY(QVariantList zones READ zones CONSTANT)
    // The zone of the running system, or UTC if it is not in zones.
    Q_PROPERTY(QString current READ current CONSTANT)
public:
    explicit TimeZones(QObject *parent = nullptr);

    QVariantList zones() const { return m_zones; }
    QString current() const { return m_current; }
    Q_INVOKABLE QVariantMap zone(const QString &id) const;
    // The time in that zone now, as "09:41".
    Q_INVOKABLE static QString time(const QString &id);

private:
    QVariantList m_zones;
    QString m_current = QStringLiteral("UTC");
};
