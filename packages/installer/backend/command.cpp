#include "command.h"

#include <QProcess>

#include <cstring>

namespace {

struct Result {
    bool started = false;
    int exitCode = -1;
    QByteArray out;
    QByteArray err;
};

Result execute(const QStringList &argv, const QByteArray &input, const QProcessEnvironment &environment)
{
    QProcess process;
    process.setProcessEnvironment(environment);
    process.start(argv.first(), argv.mid(1));
    Result result;
    if (!process.waitForStarted(-1))
        return result;
    result.started = true;
    process.write(input);
    process.closeWriteChannel();
    process.waitForFinished(-1);
    result.exitCode = process.exitStatus() == QProcess::NormalExit ? process.exitCode() : -1;
    result.out = process.readAllStandardOutput();
    result.err = process.readAllStandardError();
    return result;
}

} // namespace

QByteArray run(const QStringList &argv, const QByteArray &input, const QProcessEnvironment &environment)
{
    const Result result = execute(argv, input, environment);
    if (!result.started)
        throw Failure{QStringLiteral("command-failed"), QStringLiteral("%1 could not be started").arg(argv.first())};
    if (result.exitCode != 0) {
        // The last line of standard error is the tool's own summary.
        const QString detail = QString::fromUtf8(result.err).trimmed().section(QLatin1Char('\n'), -1);
        throw Failure{QStringLiteral("command-failed"),
                      QStringLiteral("%1 failed (%2): %3").arg(argv.first()).arg(result.exitCode).arg(detail)};
    }
    return result.out;
}

bool succeeds(const QStringList &argv, const QByteArray &input)
{
    const Result result = execute(argv, input, QProcessEnvironment::systemEnvironment());
    return result.started && result.exitCode == 0;
}

void wipe(QByteArray &secret)
{
    explicit_bzero(secret.data(), secret.size());
    secret.clear();
}
