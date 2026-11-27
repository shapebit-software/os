"""What integration tests share (the root pytest.ini loads this module): fake
services on this computer. serve() is for a fake that a test's own class
starts; the fixtures stop what they start after the test."""

import http.server
import pathlib
import subprocess
import threading

import pytest

# dbusmock's templates where they lack what ShapeBit reads, which the
# simulator uses too (development/simulator/README.md).
FAKES = pathlib.Path(__file__).resolve().parent / "fakes"


def serve(handler):
    """An HTTP server of handler on 127.0.0.1, on a free port, which answers
    on a thread of its own; its address is server.url. Whoever starts it stops
    it: server.shutdown(), then server.server_close()."""
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    server.url = f"http://127.0.0.1:{server.server_port}"
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


@pytest.fixture
def http_server():
    """http_server(handler): serve(handler), stopped after the test."""
    servers = []

    def start(handler):
        servers.append(serve(handler))
        return servers[-1]

    yield start
    for server in servers:
        server.shutdown()
        server.server_close()


@pytest.fixture(scope="session")
def system_bus():
    """A system bus of the tests' own, which programs under test and
    dbusmock's fake services find through DBUS_SYSTEM_BUS_ADDRESS; this is
    dbus-python's connection to it."""
    import dbusmock

    dbusmock.DBusTestCase.start_system_bus()
    yield dbusmock.DBusTestCase.get_dbus(system_bus=True)
    dbusmock.DBusTestCase.tearDownClass()


@pytest.fixture(scope="session")
def session_bus():
    """A session bus of the tests' own, as system_bus is a system bus."""
    import dbusmock

    dbusmock.DBusTestCase.start_session_bus()
    yield dbusmock.DBusTestCase.get_dbus(system_bus=False)
    dbusmock.DBusTestCase.tearDownClass()


@pytest.fixture
def fake(system_bus):
    """fake(name, parameters): a made-up system service on the tests' bus:
    dbusmock's template name, or fakes/name.py where that adds what dbusmock's
    lacks; its dbusmock interface, to add objects and read the calls. Stopped
    after the test."""
    import dbusmock

    servers = []

    def start(name, parameters=None):
        template = FAKES / f"{name}.py"
        server, mock = dbusmock.DBusTestCase.spawn_server_template(
            str(template) if template.exists() else name, parameters or {}, stdout=subprocess.DEVNULL, system_bus=True)
        servers.append(server)
        return mock

    yield start
    for server in servers:
        server.terminate()
        server.wait()
