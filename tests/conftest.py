"""Fixtures shared by the checks of the built OS (README.md). `host` is
Testinfra's view of the machine under test, which --machine chooses: local,
the machine pytest runs on, as in the image's own container (make test-image);
clone, a disposable clone of the installed machine (make test); or
ssh://ADDRESS[:PORT], a machine that runs already, such as the booted medium
(make disk) or a real computer (make test-guest)."""

import shutil
import sys

import pytest
import testinfra

# Generated files go in build/, never beside the sources: no bytecode for the
# modules the checks import, however pytest is started.
sys.dont_write_bytecode = True

import machine as machines  # noqa: E402


def pytest_addoption(parser):
    parser.addoption("--machine", default="local", help="local, clone, or ssh://ADDRESS[:PORT]")
    parser.addoption("--run", help="the run's name: its results go in RESULTS/<time>-NAME")
    parser.addoption("--next", help="the update test: the OCI archive of the build it moves to")
    parser.addoption("--next2", help="the update test: the OCI archive of the newer build it downloads")


@pytest.hookimpl(tryfirst=True)
def pytest_configure(config):
    config.results = None
    if config.getoption("--run", None):
        config.results = machines.new_run(config.getoption("--run"))
        config.option.xmlpath = config.option.xmlpath or str(config.results / "junit.xml")


def pytest_terminal_summary(terminalreporter, config):
    if config.results:
        terminalreporter.write_line(f"Results in {config.results}")


@pytest.fixture(scope="session")
def machine(request):
    """The machine under test, or None for the one pytest runs on. A clone is
    thrown away afterwards; what it printed and logged stays with the results."""
    where = request.config.getoption("--machine")
    results = request.config.results
    if where == "local":
        yield None
        return
    if where == "clone":
        assert results, "a clone needs --run, for its results"
        under_test = machines.installed().clone(results / "machine", machines.setting("TEST_SSH_PORT"))
    elif where.startswith("ssh://"):
        address, _, port = where.removeprefix("ssh://").removeprefix("root@").partition(":")
        under_test = machines.Machine(address=address, port=port or 22)
    else:
        raise pytest.UsageError(f"--machine={where}: expected local, clone, or ssh://ADDRESS[:PORT]")
    try:
        if under_test.directory:
            under_test.start()
        yield under_test
    finally:
        if results:
            under_test.save_diagnostics(results)
        if under_test.directory:
            under_test.stop()
            if under_test.file("serial.log").exists():
                shutil.move(under_test.file("serial.log"), results / "serial.log")
            shutil.rmtree(under_test.directory)
        else:
            under_test.close()


@pytest.fixture(scope="session")
def host(machine):
    if machine is None:
        return testinfra.get_host("local://")
    # The machine's own SSH options, with its shared connection.
    return testinfra.get_host(f"ssh://root@{machine.address}:{machine.port}",
                              ssh_extra_args=" ".join(machine.ssh_options()), controlpersist=0)


@pytest.fixture(scope="session")
def sh(host):
    """Run a shell command, fail with its output unless it succeeds, and return stdout."""

    def run(command, *args):
        result = host.run(command, *args)
        assert result.rc == 0, f"{result.command}\n{result.stdout}\n{result.stderr}"
        return result.stdout

    return run


@pytest.fixture(scope="session")
def succeeds(host):
    """Whether a shell command exits with 0."""
    return lambda command, *args: host.run(command, *args).rc == 0


@pytest.fixture(scope="session")
def updating(request):
    """Whether this is the update test, which installs with the download site's
    installer rather than the one under test."""
    return bool(request.config.getoption("--next"))


@pytest.fixture(scope="session")
def setting(request, machine):
    """A value that the run was given; a missing one is an error, not a skip.
    IMAGE_DIGEST, which ties the results to a build, is the installed disk's,
    or in the update test the build it moves to."""
    values = {}
    if machine and machine.directory:
        values["IMAGE_DIGEST"] = machines.recorded(machines.installed().disk, "image_digest")
    for option, name in (("--next", "NEXT"), ("--next2", "NEXT2")):
        if archive := request.config.getoption(option):
            values[f"{name}_VERSION"] = machines.archive_label(archive, "org.opencontainers.image.version")
            if name == "NEXT":
                values["IMAGE_DIGEST"] = machines.archive_digest(archive)

    def read(name):
        if name in values:
            return values[name]
        try:
            return machines.setting(name)
        except KeyError as error:
            raise AssertionError(f"{name} is not set") from error

    return read

