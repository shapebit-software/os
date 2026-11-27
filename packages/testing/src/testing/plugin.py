"""The pytest plugin of every test (the root pytest.ini loads it; installed,
its entry point): a test's markers say its level, and the plugin holds it to
it. A package arranges its tests/ as it likes.

- unit, a test with no level's marker: no network socket, no subprocess, and
  testing_unit_timeout seconds per test, so that it needs nothing but its
  process;
- integration (pytest.mark.integration): testing_integration_timeout seconds
  per test;
- system: exactly one system_* marker, which says the machine it runs on.

No test has two levels. The plugin marks a unit test `unit`, so that
`-m unit` selects them. A QML test, tst_*.qml anywhere in tests/, is a unit
test, which qmltestrunner runs. With CI set, a test that a skipif marker skips
fails instead: in CI, a missing tool must not pass for a passing test."""

import os
import shutil
import signal
import socket
import subprocess
import tempfile

import pytest

from testing import package_dir

SYSTEM = ("system_installed", "system_image", "system_installer", "system_update")


def level(names):
    """The level of a test with the markers names: system, integration, or
    unit; a test with two levels is an error."""
    systems = [name for name in names if name in SYSTEM]
    found = (["system"] if systems else []) + (["integration"] if "integration" in names else [])
    if len(systems) > 1 or len(found) > 1:
        raise ValueError(f"has two levels: {', '.join(sorted(set(names) & {'integration', *SYSTEM}))}")
    return found[0] if found else "unit"


def pytest_addoption(parser):
    parser.addini("testing_unit_timeout", "seconds a unit test may take", default="1")
    parser.addini("testing_integration_timeout", "seconds an integration test may take", default="60")


def pytest_configure(config):
    config.addinivalue_line("markers", "unit: a unit test, which the testing plugin marks: one with no level's marker")


def pytest_collect_file(file_path, parent):
    if file_path.name.startswith("tst_") and file_path.suffix == ".qml" and "tests" in file_path.parts:
        return QmlFile.from_parent(parent, path=file_path)
    return None


class QmlFile(pytest.File):
    def collect(self):
        yield QmlTest.from_parent(self, name=self.path.name)


class QmlFailed(Exception):
    pass


class QmlTest(pytest.Item):
    """A QML test, which qmltestrunner runs offscreen from a copy beside its
    package's scripts (src/**/*.js): beside the sources, the qmldir would
    import modules that load only in their own program, such as Quickshell."""

    def runtest(self):
        # Fedora names Qt 6's runner with a suffix; qt6-qtdeclarative-devel has it.
        runner = shutil.which("qmltestrunner-qt6") or shutil.which("qmltestrunner")
        assert runner, "qmltestrunner is missing: install qt6-qtdeclarative-devel"
        with tempfile.TemporaryDirectory() as copy:
            for script in (package_dir(self.path) / "src").rglob("*.js"):
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


@pytest.hookimpl(tryfirst=True)
def pytest_collection_modifyitems(session, config, items):
    """Before -m selects: marks unit tests, and refuses a test of two levels."""
    errors = []
    for item in items:
        try:
            found = level({mark.name for mark in item.iter_markers()})
        except ValueError as error:
            errors.append(f"{item.nodeid}: {error}")
            continue
        item.stash[LEVEL] = found
        if found == "unit":
            item.add_marker(pytest.mark.unit)
    if errors:
        raise pytest.UsageError("\n".join(errors))


LEVEL = pytest.StashKey[str]()


class Forbidden(Exception):
    """What a unit test may not do."""


def forbid(what):
    def refuse(*args, **kwargs):
        raise Forbidden(f"a unit test may not {what}: mark it pytest.mark.integration")

    return refuse


class Socket(socket.socket):
    """A socket of a unit test: of the computer's own, not the network."""

    def __init__(self, family=-1, type=-1, proto=-1, fileno=None):
        if fileno is None and family in (-1, socket.AF_INET, socket.AF_INET6):
            raise Forbidden("a unit test may not open a network socket: mark it pytest.mark.integration")
        super().__init__(family, type, proto, fileno)


class TimedOut(Exception):
    pass


@pytest.hookimpl(wrapper=True)
def pytest_runtest_call(item):
    # Only a test's own code is held to its level, not a runner the plugin
    # starts, such as qmltestrunner.
    found = item.stash.get(LEVEL, None) if isinstance(item, pytest.Function) else None
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
