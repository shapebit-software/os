#include "timezones.h"

#include <QDateTime>
#include <QTimeZone>

namespace {

// The database also has aliases and legacy names ("US/Eastern", "EST5EDT");
// only the geographic zones are offered.
const QStringList regions{QStringLiteral("Africa"), QStringLiteral("America"), QStringLiteral("Antarctica"),
                          QStringLiteral("Arctic"), QStringLiteral("Asia"), QStringLiteral("Atlantic"),
                          QStringLiteral("Australia"), QStringLiteral("Europe"), QStringLiteral("Indian"),
                          QStringLiteral("Pacific")};

QString offset(const QTimeZone &zone)
{
    const int minutes = zone.offsetFromUtc(QDateTime::currentDateTimeUtc()) / 60;
    QString text = QStringLiteral("UTC");
    if (minutes != 0)
        text += (minutes < 0 ? QStringLiteral("−") : QStringLiteral("+")) + QString::number(qAbs(minutes) / 60);
    if (minutes % 60 != 0)
        text += QStringLiteral(":%1").arg(qAbs(minutes) % 60, 2, 10, QLatin1Char('0'));
    return text;
}

QVariantMap describe(const QString &id)
{
    return {{QStringLiteral("id"), id},
            {QStringLiteral("city"), id.section(QLatin1Char('/'), -1).replace(QLatin1Char('_'), QLatin1Char(' '))},
            {QStringLiteral("region"), id.contains(QLatin1Char('/')) ? id.section(QLatin1Char('/'), 0, 0) : QString()},
            {QStringLiteral("offset"), offset(QTimeZone(id.toUtf8()))}};
}

} // namespace

TimeZones::TimeZones(QObject *parent) : QObject(parent)
{
    const QString system = QString::fromUtf8(QTimeZone::systemTimeZoneId());
    m_zones.append(describe(m_current));
    for (const QByteArray &bytes : QTimeZone::availableTimeZoneIds()) {
        const QString id = QString::fromUtf8(bytes);
        if (!regions.contains(id.section(QLatin1Char('/'), 0, 0)))
            continue;
        m_zones.append(describe(id));
        if (id == system)
            m_current = id;
    }
}

QVariantMap TimeZones::zone(const QString &id) const
{
    return describe(id);
}

QString TimeZones::time(const QString &id)
{
    return QDateTime::currentDateTimeUtc().toTimeZone(QTimeZone(id.toUtf8())).toString(QStringLiteral("HH:mm"));
}
