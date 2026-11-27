"""What integration tests share (the root pytest.ini loads this module): fake
services on this computer. serve() is for a fake that a test's own class
starts; the fixtures stop what they start after the test."""

import http.server
import threading

import pytest


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
