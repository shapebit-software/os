// Runs external tools. Every argument list is built by the backend; nothing
// the frontend sends is ever executed.
#pragma once

#include <QByteArray>
#include <QProcessEnvironment>
#include <QString>
#include <QStringList>

// A failed step: a stable code for the frontend and a message without secrets.
struct Failure {
    QString code;
    QString message;
};

// Runs argv to completion and returns its standard output. Throws Failure
// (code "command-failed") if it cannot start or exits with an error.
QByteArray run(const QStringList &argv, const QByteArray &input = {},
               const QProcessEnvironment &environment = QProcessEnvironment::systemEnvironment());

// As run(), but reports failure by returning false instead of throwing.
bool succeeds(const QStringList &argv, const QByteArray &input = {});

// Overwrites a secret before its memory is released.
void wipe(QByteArray &secret);
