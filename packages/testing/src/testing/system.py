"""What the system tests share (../../README.md), a pytest plugin that the
make targets of the system tests load (-p testing.system). `host` is
Testinfra's view of the machine under test, which --machine chooses:
container://IMAGE, a container of the image, which Testinfra reaches through
the engine (make test-system-image); clone, a disposable clone of the
installed machine (make test-system); or ssh://ADDRESS[:PORT], a machine that
runs already, such as the booted medium (make disk) or a real computer
(make test-system GUEST=...)."""

import shlex
import shutil
import subprocess
import sys

import pytest
import testinfra

# Generated files go in build/, never beside the sources: no bytecode for the
# modules the checks import, however pytest is started.
sys.dont_write_bytecode = True

from testing import machine as machines  # noqa: E402


def pytest_addoption(parser):
    parser.addoption("--machine", help="container://IMAGE, clone, or ssh://ADDRESS[:PORT]")
    parser.addoption("--run", help="the run's name: its results go in RESULTS/<time>-NAME")
    parser.addoption("--next", help="the update test: the OCI archive of the build it moves to")
    parser.addoption("--next2", help="the update test: the OCI archive of the newer build it downloads")


@pytest.hookimpl(tryfirst=True)
def pytest_configure(config):
    config.results = None
    if config.getoption("--run", None):
        config.results = machines.new_run(config.getoption("--run"))
        config.option.xmlpath = config.option.xmlpath or str(config.results / "junit.xml")


def pytest_collection_modifyitems(config, items):
    """The update test (--next): the system_update tests marked when="before"
    run first and those marked when="after" last, around the installed
    system's tests, but those marked update=False, such as the reboots that
    the update test does enough of."""
    if not config.getoption("--next", None):
        return
    kept, dropped = [], []
    for item in items:
        installed = item.get_closest_marker("system_installed")
        (dropped if installed and installed.kwargs.get("update") is False else kept).append(item)

    def place(item):
        update = item.get_closest_marker("system_update")
        return {"before": 0, "after": 2}.get(update.kwargs.get("when"), 1) if update else 1

    if dropped:
        config.hook.pytest_deselected(items=dropped)
    items[:] = sorted(kept, key=place)


def pytest_terminal_summary(terminalreporter, config):
    if config.results:
        terminalreporter.write_line(f"Results in {config.results}")


class Container:
    """A container of IMAGE, with no network and nothing added, but the checks
    themselves, read-only, for files that a check gives a program of the image;
    removed afterwards. Testinfra runs commands in it with `ENGINE exec`."""

    def __init__(self, image):
        self.engine = shlex.split(machines.setting("ENGINE"))
        packages = machines.ROOT / "packages"
        self.id = subprocess.run([*self.engine, "run", "-d", "--rm", "--network", "none",
                                  "-v", f"{packages}:/packages:ro,z", "--entrypoint", "sleep", image, "infinity"],
                                 check=True, capture_output=True, text=True).stdout.strip()

    def host(self):
        backend = "docker" if self.engine[0] == "docker" else "podman"
        return testinfra.get_host(f"{backend}://{self.id}")

    def remove(self):
        subprocess.run([*self.engine, "rm", "-f", self.id], capture_output=True)


@pytest.fixture(scope="session")
def machine(request):
    """The machine under test. A container or a clone is thrown away
    afterwards; what a clone printed and logged stays with the results."""
    where = request.config.getoption("--machine") or ""
    results = request.config.results
    if where.startswith("container://"):
        container = Container(where.removeprefix("container://"))
        try:
            yield container
        finally:
            container.remove()
        return
    if where == "clone":
        assert results, "a clone needs --run, for its results"
        under_test = machines.installed().clone(results / "machine", machines.setting("TEST_SSH_PORT"))
    elif where.startswith("ssh://"):
        address, _, port = where.removeprefix("ssh://").removeprefix("root@").partition(":")
        under_test = machines.Machine(address=address, port=port or 22)
    else:
        raise pytest.UsageError(f"--machine={where}: expected container://IMAGE, clone, or ssh://ADDRESS[:PORT]")
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
    if isinstance(machine, Container):
        return machine.host()
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
def wait_until():
    """wait_until(predicate, timeout=..., interval=...): the predicate's last
    value, once it is true or the time is up (machine.py)."""
    return machines.wait_until


@pytest.fixture(scope="session")
def recovery_key(machine):
    """The installed disk's recovery key, which only the host knows; skips
    on a machine whose key is not known."""
    if not getattr(machine, "directory", None):
        pytest.skip("only the installed disk's recovery key is known")
    return machines.path("RECOVERY_KEY").read_text()


@pytest.fixture(scope="session")
def serve_build():
    """serve_build(archive, tag): an image archive's build, served from the
    local update registry under tag (machine.py publish)."""
    return machines.publish


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
    if getattr(machine, "directory", None):
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

