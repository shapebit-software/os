"""The shared fixtures, with made-up services."""

import http.server
import subprocess
import urllib.request

from testing.fixtures import serve


class Hello(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(self.path.encode())


def test_serve_answers_at_its_url_until_it_is_stopped():
    server = serve(Hello)
    try:
        with urllib.request.urlopen(f"{server.url}/hello") as response:
            assert response.read() == b"/hello"
    finally:
        server.shutdown()
        server.server_close()


def test_the_http_server_fixture_serves_each_handler_on_its_own_port(http_server):
    first, second = http_server(Hello), http_server(Hello)
    assert first.url != second.url
    with urllib.request.urlopen(f"{second.url}/x") as response:
        assert response.read() == b"/x"


def test_the_system_bus_is_the_tests_own(system_bus):
    names = system_bus.list_names()
    assert "org.freedesktop.DBus" in names
    # A program started now finds the same bus, not the computer's.
    out = subprocess.run(["dbus-send", "--system", "--print-reply", "--dest=org.freedesktop.DBus", "/",
                          "org.freedesktop.DBus.GetId"], capture_output=True, text=True, check=True).stdout
    assert system_bus.get_object("org.freedesktop.DBus", "/").GetId(
        dbus_interface="org.freedesktop.DBus") in out
