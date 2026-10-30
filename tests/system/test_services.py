"""The installed system: services that run without anyone signed in."""

import json

import pytest
from conftest import wait_until


@pytest.mark.parametrize("unit", ["sddm", "sshd", "NetworkManager", "systemd-homed", "os-update.timer"])
def test_unit_is_running(host, unit):
    assert host.service(unit).is_running


def test_login_screen_shows_its_greeter(succeeds):
    # SDDM starts its greeter after the system reports that it is up.
    assert wait_until(lambda: succeeds("pgrep -u sddm -f sddm-greeter"))


def test_battery_service_answers(sh):
    sh("busctl call org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.DBus.Peer Ping")


def test_system_update_status_is_there_for_the_shell(host):
    assert isinstance(json.loads(host.file("/run/os-update/status.json").content_string), dict)
