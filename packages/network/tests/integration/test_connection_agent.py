"""The connection agent, as packages/network/Makefile installs it, between made-up
NetworkManager and BlueZ (python-dbusmock) on a system bus of its own, and a
made-up shell on its standard input and output: it joins networks, asks for
passwords and pairing codes, and pairs devices."""

import json
import pathlib
import queue
import subprocess
import threading
import time

import dbus
import dbusmock
import pytest

ROOT = pathlib.Path(__file__).parents[4]
NM = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
AGENT = "/org/freedesktop/NetworkManager/SecretAgent"
BLUEZ = "org.bluez"
BLUEZ_AGENT = "/desktop/agent"
DEVICE = "/org/bluez/hci0/dev_AA"
UNKNOWN = "/org/bluez/hci0/dev_BB"
# NetworkManager's access point security flags.
PSK, SAE = 0x100, 0x400


@pytest.fixture(scope="session")
def program(tmp_path_factory):
    destination = tmp_path_factory.mktemp("network")
    subprocess.run(["make", "-s", "-C", ROOT / "packages" / "network", "install", f"DESTDIR={destination}"],
                   check=True)
    return destination / "usr" / "libexec" / "desktop" / "connection-agent"


def mock(bus, name, path, interface):
    server = dbusmock.DBusTestCase.spawn_server(name, path, interface, system_bus=True,
                                                stdout=subprocess.DEVNULL)
    return server, dbus.Interface(bus.get_object(name, path), dbusmock.MOCK_IFACE)


def point(ssid, strength, rsn=0):
    return {"Ssid": dbus.ByteArray(ssid.encode()), "Strength": dbus.Byte(strength), "Flags": dbus.UInt32(0),
            "WpaFlags": dbus.UInt32(0), "RsnFlags": dbus.UInt32(rsn)}


class Agent:
    """The agent and what it tells the shell."""

    def __init__(self, program, bus):
        self.bus = bus
        self.process = subprocess.Popen([program], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        self.told = queue.Queue()
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.process.stdout:
            self.told.put(json.loads(line))

    def send(self, message):
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def expect(self, key, timeout=10):
        """The next message with KEY; others before it are passed over."""
        end = time.monotonic() + timeout
        while (left := end - time.monotonic()) > 0:
            try:
                message = self.told.get(timeout=left)
            except queue.Empty:
                break
            if key in message:
                return message
        raise AssertionError(f"the agent told no {key!r}")

    def name(self):
        """The agent's unique name on the bus, by its process."""
        daemon = dbus.Interface(self.bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"),
                                "org.freedesktop.DBus")
        for name in daemon.ListNames():
            if name.startswith(":") and daemon.GetConnectionUnixProcessID(name) == self.process.pid:
                return name
        raise AssertionError("the agent is not on the bus")

    def call(self, path, method, *args):
        """Calls the agent as NetworkManager or BlueZ would; the reply comes
        from communicate()."""
        return subprocess.Popen(["gdbus", "call", "--system", "--dest", self.name(), "--object-path", path,
                                 "--method", method, *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True)


def wait_for(predicate, timeout=10):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if result := predicate():
            return result
        time.sleep(0.05)
    raise AssertionError("it did not happen")


def reply(call):
    out, err = call.communicate(timeout=10)
    return out.strip() or err.strip()


@pytest.fixture
def services(system_bus):
    """NetworkManager with a Wi-Fi device that sees two access points of
    "Home" and an open "Cafe", and BlueZ with one device."""
    nm_server, nm = mock(system_bus, NM, NM_PATH, NM)
    nm.AddMethod("", "GetDevices", "", "ao", 'ret = [dbus.ObjectPath("/devices/wifi")]')
    nm.AddMethod("", "AddAndActivateConnection", "a{sa{sv}}oo", "oo",
                 'ret = (dbus.ObjectPath("/connections/1"), dbus.ObjectPath("/active/1"))')
    nm.AddObject(NM_PATH + "/AgentManager", NM + ".AgentManager", {},
                 [("RegisterWithCapabilities", "su", "", "")])
    nm.AddObject("/devices/wifi", NM + ".Device", {"DeviceType": dbus.UInt32(2)}, [])
    dbus.Interface(system_bus.get_object(NM, "/devices/wifi"), dbusmock.MOCK_IFACE).AddProperties(
        NM + ".Device.Wireless", {"AccessPoints": dbus.Array(
            [dbus.ObjectPath(f"/points/{n}") for n in (1, 2, 3)], signature="o")})
    nm.AddObject("/points/1", NM + ".AccessPoint", point("Home", 40, PSK), [])
    nm.AddObject("/points/2", NM + ".AccessPoint", point("Home", 80, PSK), [])
    nm.AddObject("/points/3", NM + ".AccessPoint", point("Cafe", 60), [])
    nm.AddObject("/connections/1", NM + ".Settings.Connection", {}, [("Delete", "", "", "")])
    nm.AddObject("/active/1", NM + ".Connection.Active", {"State": dbus.UInt32(1)}, [])

    bluez_server, bluez = mock(system_bus, BLUEZ, "/org/bluez", "org.bluez.AgentManager1")
    bluez.AddMethods("", [("RegisterAgent", "os", "", ""), ("RequestDefaultAgent", "o", "", "")])
    bluez.AddObject(DEVICE, "org.bluez.Device1",
                    {"Alias": "Headphones", "Paired": False, "Trusted": False},
                    [("Pair", "", "", ""), ("Connect", "", "", ""), ("CancelPairing", "", "", "")])
    bluez.AddObject(UNKNOWN, "org.bluez.Device1", {"Alias": "Keyboard", "Paired": False, "Trusted": False}, [])
    yield nm, bluez
    for server in (nm_server, bluez_server):
        server.terminate()
        server.wait()


def mocked(bus, name, path):
    return dbus.Interface(bus.get_object(name, path), dbusmock.MOCK_IFACE)


@pytest.fixture
def agent(program, system_bus, services):
    nm, bluez = services
    agent = Agent(program, system_bus)
    # Ready once it is both agents.
    wait_for(lambda: mocked(system_bus, NM, NM_PATH + "/AgentManager").GetMethodCalls("RegisterWithCapabilities"))
    wait_for(lambda: bluez.GetMethodCalls("RequestDefaultAgent"))
    yield agent
    agent.process.kill()
    agent.process.wait()


def test_it_is_networkmanagers_and_bluezs_agent(agent, services, system_bus):
    nm, bluez = services
    registered = mocked(system_bus, NM, NM_PATH + "/AgentManager").GetMethodCalls("RegisterWithCapabilities")
    assert [list(call[1]) for call in registered] == [["desktop.connection-agent", 0]]
    assert [list(call[1]) for call in bluez.GetMethodCalls("RegisterAgent")] == [[BLUEZ_AGENT, "KeyboardDisplay"]]
    assert [list(call[1]) for call in bluez.GetMethodCalls("RequestDefaultAgent")] == [[BLUEZ_AGENT]]


def joined(agent, services, system_bus, state, reason):
    """Joins "Home", then the activation goes to STATE for REASON."""
    nm, _ = services
    agent.send({"join": "Home", "password": "secret"})
    call = wait_for(lambda: nm.GetMethodCalls("AddAndActivateConnection"))[0]
    active = mocked(system_bus, NM, "/active/1")
    # Again until it is told, since the agent may not yet listen.
    event = None
    while event is None:
        active.EmitSignal(NM + ".Connection.Active", "StateChanged", "uu", [dbus.UInt32(state), dbus.UInt32(reason)])
        try:
            event = agent.expect("event", timeout=0.2)
        except AssertionError:
            pass
    return call, event


def test_it_joins_the_strongest_access_point_with_the_password(agent, services, system_bus):
    call, event = joined(agent, services, system_bus, 2, 0)
    settings, device, access_point = call[1]
    assert (device, access_point) == ("/devices/wifi", "/points/2")
    assert settings["connection"] == {"type": "802-11-wireless", "id": "Home"}
    assert bytes(settings["802-11-wireless"]["ssid"]) == b"Home"
    assert settings["802-11-wireless"]["mode"] == "infrastructure"
    assert settings["802-11-wireless-security"] == {"key-mgmt": "wpa-psk", "psk": "secret"}
    assert event == {"event": "join", "target": "Home", "ok": True, "reason": ""}
    assert mocked(system_bus, NM, "/connections/1").GetMethodCalls("Delete") == []


def test_a_wrong_password_removes_the_new_connection(agent, services, system_bus):
    _, event = joined(agent, services, system_bus, 4, 9)
    assert event == {"event": "join", "target": "Home", "ok": False, "reason": "Wrong password"}
    wait_for(lambda: mocked(system_bus, NM, "/connections/1").GetMethodCalls("Delete"))


def test_an_open_network_needs_no_security(agent, services):
    nm, _ = services
    agent.send({"join": "Cafe", "password": ""})
    settings, _, access_point = wait_for(lambda: nm.GetMethodCalls("AddAndActivateConnection"))[0][1]
    assert access_point == "/points/3"
    assert "802-11-wireless-security" not in settings


def test_a_network_out_of_reach_is_not_found(agent, services):
    agent.send({"join": "Nowhere", "password": "x"})
    assert agent.expect("event") == {"event": "join", "target": "Nowhere", "ok": False,
                                     "reason": "Network not found"}
    assert services[0].GetMethodCalls("AddAndActivateConnection") == []


def get_secrets(agent, flags=1, setting="802-11-wireless-security"):
    return agent.call(AGENT, NM + ".SecretAgent.GetSecrets",
                      # The SSID's bytes; gdbus's b'Home' would end in a NUL.
                      "{'802-11-wireless': {'ssid': <[byte 0x48, 0x6f, 0x6d, 0x65]>}, 'connection': {'id': <'Home'>}}",
                      "/connections/1", setting, "[]", str(flags))


def test_it_asks_for_a_password_and_gives_it_to_networkmanager(agent):
    call = get_secrets(agent)
    question = agent.expect("ask")
    assert question == {"ask": question["ask"], "kind": "secret", "icon": "network-wireless",
                        "title": "Password for “Home”", "subtitle": "The network needs its password.",
                        "fields": [{"id": "password", "label": "Password", "secret": True}],
                        "grant": "Join", "deny": "Cancel"}
    agent.send({"answer": question["ask"], "granted": True, "fields": {"password": "typed"}})
    assert reply(call) == "({'802-11-wireless-security': {'psk': <'typed'>}},)"


def test_it_asks_again_when_the_password_did_not_work(agent):
    call = get_secrets(agent, flags=1 | 2)
    question = agent.expect("ask")
    assert question["subtitle"] == "The password did not work. Type it again."
    agent.send({"answer": question["ask"], "granted": False})
    assert "SecretAgent.UserCanceled" in reply(call)


def test_it_asks_nothing_when_networkmanager_may_not_ask(agent):
    assert "SecretAgent.NoSecrets" in reply(get_secrets(agent, flags=0))


def test_networkmanager_withdraws_its_question(agent):
    call = get_secrets(agent)
    question = agent.expect("ask")
    cancel = agent.call(AGENT, NM + ".SecretAgent.CancelGetSecrets", "/connections/1", "802-11-wireless-security")
    assert reply(cancel) == "()"
    assert agent.expect("cancel") == {"cancel": question["ask"]}
    assert "SecretAgent.UserCanceled" in reply(call)


def test_it_asks_to_confirm_a_pairing_code(agent):
    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.RequestConfirmation", DEVICE, "123")
    question = agent.expect("ask")
    assert question == {"ask": question["ask"], "kind": "pairing", "icon": "bluetooth", "deny": "Cancel",
                        "title": "Pair with Headphones?", "subtitle": "Check that it shows the same code.",
                        "code": "000123", "grant": "Pair"}
    agent.send({"answer": question["ask"], "granted": True})
    assert reply(call) == "()"


def test_a_refused_pairing_is_rejected(agent):
    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.RequestAuthorization", DEVICE)
    question = agent.expect("ask")
    assert question["title"] == "Pair with Headphones?"
    agent.send({"answer": question["ask"], "granted": False})
    assert "org.bluez.Error.Rejected" in reply(call)


def test_it_asks_for_a_passkey_and_a_pin(agent):
    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.RequestPasskey", DEVICE)
    question = agent.expect("ask")
    assert question["fields"] == [{"id": "passkey", "label": "Passkey"}]
    agent.send({"answer": question["ask"], "granted": True, "fields": {"passkey": "12 34 56 78"}})
    assert reply(call) == "(uint32 123456,)"

    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.RequestPinCode", DEVICE)
    question = agent.expect("ask")
    assert question["title"] == "PIN for Headphones"
    agent.send({"answer": question["ask"], "granted": True, "fields": {"pin": "0000"}})
    assert reply(call) == "('0000',)"


def test_it_shows_a_code_to_type_until_bluez_cancels(agent):
    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.DisplayPasskey", DEVICE, "42", "0")
    assert reply(call) == "()"
    question = agent.expect("ask")
    assert (question["code"], question["subtitle"]) == ("000042", "Type this code on the device, then Enter.")
    assert "grant" not in question
    assert reply(agent.call(BLUEZ_AGENT, "org.bluez.Agent1.Cancel")) == "()"
    assert agent.expect("cancel") == {"cancel": question["ask"]}


def test_bluez_withdraws_its_question(agent):
    call = agent.call(BLUEZ_AGENT, "org.bluez.Agent1.RequestConfirmation", DEVICE, "7")
    question = agent.expect("ask")
    assert reply(agent.call(BLUEZ_AGENT, "org.bluez.Agent1.Cancel")) == "()"
    assert agent.expect("cancel") == {"cancel": question["ask"]}
    assert "org.bluez.Error.Rejected" in reply(call)


def test_only_paired_devices_may_use_services(agent, system_bus):
    uuid = "0000110b-0000-1000-8000-00805f9b34fb"
    assert "org.bluez.Error.Rejected" in reply(agent.call(BLUEZ_AGENT, "org.bluez.Agent1.AuthorizeService",
                                                          DEVICE, uuid))
    dbus.Interface(system_bus.get_object(BLUEZ, DEVICE), dbus.PROPERTIES_IFACE).Set(
        "org.bluez.Device1", "Paired", True)
    assert reply(agent.call(BLUEZ_AGENT, "org.bluez.Agent1.AuthorizeService", DEVICE, uuid)) == "()"


def test_it_pairs_trusts_and_connects_a_device(agent, system_bus):
    agent.send({"pair": DEVICE})
    assert agent.expect("event") == {"event": "pair", "target": DEVICE, "ok": True, "reason": ""}
    device = mocked(system_bus, BLUEZ, DEVICE)
    assert device.GetMethodCalls("Pair") and device.GetMethodCalls("Connect")
    properties = dbus.Interface(system_bus.get_object(BLUEZ, DEVICE), dbus.PROPERTIES_IFACE)
    assert properties.Get("org.bluez.Device1", "Trusted") == True  # noqa: E712, a dbus.Boolean


def test_a_failed_pairing_is_told(agent):
    # The made-up device has no Pair method.
    agent.send({"pair": UNKNOWN})
    event = agent.expect("event")
    assert (event["target"], event["ok"]) == (UNKNOWN, False) and event["reason"]


def test_a_message_it_cannot_read_is_passed_over(agent):
    agent.send({"answer": 999, "granted": True})
    agent.process.stdin.write("not json\n")
    agent.process.stdin.flush()
    agent.send({"join": "Nowhere", "password": ""})
    assert agent.expect("event")["target"] == "Nowhere"


def test_it_ends_when_the_shell_goes(agent):
    agent.process.stdin.close()
    assert agent.process.wait(timeout=10) == 0
