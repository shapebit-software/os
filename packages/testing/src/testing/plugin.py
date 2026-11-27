"""The pytest plugin of every test (the root pytest.ini loads it): the folder
a test is in, tests/LEVEL/, says its level, and the plugin holds it to it.

- unit: no network socket, no subprocess, and testing_unit_timeout seconds
  per test, so that a unit test needs nothing but its process;
- integration: testing_integration_timeout seconds per test;
- system: exactly one system_* marker, which says the machine it runs on;
  no test of another level carries one.

A QML test, tests/unit/tst_*.qml, is collected too: qmltestrunner runs it.

testing_layout = warn reports a test outside tests/LEVEL/; strict fails it.
With CI set, a test that a skipif marker skips fails instead: in CI, a missing
tool must not pass for a passing test."""

import os
import shutil
import signal
import socket
import subprocess
import tempfile
import warnings

import pytest

LEVELS = ("unit", "integration", "system", "e2e")
SYSTEM = ("system_installed", "system_image", "system_installer", "system_update")


def level(path):
    """The level of the test at path: the folder after its last tests/, or None."""
    parts = path.parts
    for index in range(len(parts) - 2, -1, -1):
        if parts[index] == "tests":
            return parts[index + 1] if parts[index + 1] in LEVELS else None
    return None


def pytest_addoption(parser):
    parser.addini("testing_layout", "warn or strict: a test outside tests/LEVEL/", default="warn")
    parser.addini("testing_unit_timeout", "seconds a unit test may take", default="1")
    parser.addini("testing_integration_timeout", "seconds an integration test may take", default="60")


def pytest_collect_file(file_path, parent):
    if file_path.name.startswith("tst_") and file_path.suffix == ".qml" and level(file_path) == "unit":
        return QmlFile.from_parent(parent, path=file_path)
    return None


class QmlFile(pytest.File):
    def collect(self):
        yield QmlTest.from_parent(self, name=self.path.name)


class QmlFailed(Exception):
    pass


class QmlTest(pytest.Item):
    """A QML test, which qmltestrunner runs offscreen from a copy beside its
    feature's scripts (src/**/*.js): beside the sources, the qmldir would
    import modules that load only in their own program, such as Quickshell."""

    def runtest(self):
        # Fedora names Qt 6's runner with a suffix; qt6-qtdeclarative-devel has it.
        runner = shutil.which("qmltestrunner-qt6") or shutil.which("qmltestrunner")
        assert runner, "qmltestrunner is missing: install qt6-qtdeclarative-devel"
        with tempfile.TemporaryDirectory() as copy:
            for script in (self.path.parents[2] / "src").rglob("*.js"):
                shutil.copy(script, copy)
            shutil.copy(self.path, copy)
            result = subprocess.run([runner, "-platform", "offscreen", "-input", os.path.join(copy, self.path.name)],
                                    capture_output=True, text=True, check=False)
        if result.returncode:
            raise QmlFailed(result.stdout + result.stderr)

    def repr_failure(self, excinfo):
        if isinstance(excinfo.value, QmlFailed):
            return str(excinfo.value)
        return super().repr_failure(excinfo)

    def reportinfo(self):
        return self.path, None, self.name


class LayoutWarning(UserWarning):
    pass


def pytest_collection_modifyitems(session, config, items):
    strict = config.getini("testing_layout") == "strict"
    errors = []
    reported = set()
    for item in items:
        path = item.path
        found = level(path)
        systems = {mark.name for mark in item.iter_markers() if mark.name in SYSTEM}
        if found is None:
            if path not in reported:
                reported.add(path)
                message = f"{path}: not in a tests/LEVEL/ folder ({', '.join(LEVELS)})"
                if strict:
                    errors.append(message)
                else:
                    warnings.warn(LayoutWarning(message))
        elif found == "system" and len(systems) != 1:
            errors.append(f"{item.nodeid}: a system test has exactly one of {', '.join(SYSTEM)}")
        elif found != "system" and systems:
            errors.append(f"{item.nodeid}: only a system test has {', '.join(sorted(systems))}")
    if errors:
        raise pytest.UsageError("\n".join(errors))


class Forbidden(Exception):
    """What a unit test may not do."""


def forbid(what):
    def refuse(*args, **kwargs):
        raise Forbidden(f"a unit test may not {what}: it belongs in tests/integration/")

    return refuse


class Socket(socket.socket):
    """A socket of a unit test: of the computer's own, not the network."""

    def __init__(self, family=-1, type=-1, proto=-1, fileno=None):
        if fileno is None and family in (-1, socket.AF_INET, socket.AF_INET6):
            raise Forbidden("a unit test may not open a network socket: it belongs in tests/integration/")
        super().__init__(family, type, proto, fileno)


class TimedOut(Exception):
    pass


@pytest.hookimpl(wrapper=True)
def pytest_runtest_call(item):
    # Only a test's own code is held to its level, not a runner the plugin
    # starts, such as qmltestrunner.
    found = level(item.path) if isinstance(item, pytest.Function) else None
    seconds = {"unit": item.config.getini("testing_unit_timeout"),
               "integration": item.config.getini("testing_integration_timeout")}.get(found)
    with pytest.MonkeyPatch.context() as patch:
        if found == "unit":
            patch.setattr(socket, "socket", Socket)
            patch.setattr(subprocess.Popen, "__init__", forbid("start a process"))
            patch.setattr(os, "system", forbid("start a process"))
            patch.setattr(os, "posix_spawn", forbid("start a process"))
            patch.setattr(os, "fork", forbid("start a process"))
        if seconds:
            def late(signum, frame):
                raise TimedOut(f"a {found} test may take {seconds} s (testing_{found}_timeout)")

            previous = signal.signal(signal.SIGALRM, late)
            signal.setitimer(signal.ITIMER_REAL, float(seconds))
        try:
            return (yield)
        finally:
            if seconds:
                signal.setitimer(signal.ITIMER_REAL, 0)
                signal.signal(signal.SIGALRM, previous)


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item, call):
    report = yield
    if report.skipped and call.when == "setup" and os.environ.get("CI"):
        reasons = [mark.kwargs.get("reason", "") for mark in item.iter_markers("skipif")
                   if mark.args and mark.args[0]]
        if reasons:
            report.outcome = "failed"
            report.longrepr = f"skipped in CI, where nothing may be missing: {reasons[0]}"
    return report
