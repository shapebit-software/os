"""The installed system: networking, within QEMU's user network: the checks need
no connection beyond the host."""

import json

import pytest

pytestmark = pytest.mark.installed


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


def test_gateway_answers_over_tcp(host):
    # From the machine, with its bash's /dev/tcp. Whether the host listens on
    # this port does not matter: a refusal is an answer; timeout's 124 is none.
    result = host.run(f"timeout 10 bash -c 'exec 3<>/dev/tcp/{GATEWAY}/22'")
    assert result.rc == 0 or "Connection refused" in result.stderr, result.stderr


def test_sshd_accepts_connections(sh):
    assert sh("timeout 10 bash -c 'exec 3<>/dev/tcp/127.0.0.1/22; head -c 8 <&3'") == "SSH-2.0-"
