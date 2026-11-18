"""The installed system: networking, within QEMU's user network: the checks need
no connection beyond the host."""

import json
import socket

GATEWAY = "10.0.2.2"


def test_networkmanager_connected_the_wired_network(sh):
    assert sh("nmcli -g STATE general").strip() == "connected"
    devices = [line.split(":") for line in sh("nmcli -t -f TYPE,STATE device").splitlines()]
    assert ["ethernet", "connected"] in devices


def test_interface_has_an_address_by_dhcp(sh):
    links = json.loads(sh("ip -json -4 address show scope global"))
    assert [address for link in links for address in link["addr_info"]]


def test_default_route_is_the_gateway(sh):
    routes = json.loads(sh("ip -json route show default"))
    assert routes and routes[0]["gateway"] == GATEWAY


def test_a_name_server_is_configured(sh):
    assert "nameserver" in sh("cat /etc/resolv.conf")


def test_gateway_answers_over_tcp():
    # Whether the host listens on this port does not matter: a refusal is an answer.
    try:
        socket.create_connection((GATEWAY, 22), timeout=10).close()
    except ConnectionRefusedError:
        pass


def test_sshd_accepts_connections():
    with socket.create_connection(("127.0.0.1", 22), timeout=10) as connection:
        assert connection.recv(16).startswith(b"SSH-2.0-")
