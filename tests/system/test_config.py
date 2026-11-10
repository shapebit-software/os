"""The installed system: what the installer was told, and the first owner."""

import json
import os
import re

import pytest


def test_locale_is_the_one_given_to_the_installer(sh, setting):
    assert f"System Locale: LANG={setting('LOCALE')}" in sh("localectl status")


def test_keyboard_layout_is_the_one_given_to_the_installer(sh, setting):
    status = sh("localectl status")
    layout = setting("KEYBOARD_LAYOUT")
    assert re.search(rf"VC Keymap: +{layout}$", status, re.M)
    assert re.search(rf"X11 Layout: +{layout}$", status, re.M)


def test_time_zone_is_the_one_given_to_the_installer(sh, setting):
    assert sh("timedatectl show --property=Timezone --value").strip() == setting("TIME_ZONE")


def test_first_owner_administers_the_machine(host, setting):
    assert "wheel" in host.user(setting("OWNER_NAME")).groups


def test_first_owner_has_a_luks2_home(sh, setting):
    record = json.loads(sh("homectl inspect -j %s", setting("OWNER_NAME")))
    assert [binding["storage"] for binding in record["binding"].values()] == ["luks"]


@pytest.mark.skipif(bool(os.environ.get("NEXT_VERSION")),
                    reason="the update test installs with the download site's installer, not the one under test")
def test_first_owner_home_leaves_room_for_updates(sh, setting):
    # The installer sizes the home and turns rebalancing off, so that systemd-
    # homed never grows it into the space an update needs: a home that the disk
    # cannot hold whole does not open, and its owner cannot sign in. The
    # settings must apply to this machine: bound to the installer medium's
    # machine ID, they once left homed free to grow the home over the disk.
    record = json.loads(sh("homectl inspect -j %s", setting("OWNER_NAME")))
    machine = sh("cat /etc/machine-id").strip()

    def ids(section, key):
        value = section.get(key, [])
        return [value] if isinstance(value, str) else value

    sections = [record, *record.get("perMachine", [])]
    for section in sections[1:]:
        assert "matchMachineId" not in section or machine in ids(section, "matchMachineId"), section
        assert machine not in ids(section, "matchNotMachineId"), section
    assert any(section.get("rebalanceWeight") in (0, False) for section in sections)
    assert all(section.get("rebalanceWeight", 0) in (0, False) for section in sections)
    assert any("diskSize" in section for section in sections)


def test_login_screen_lists_the_first_owner(host, setting):
    # SDDM lists the users that enumerate through NSS, within its UID range.
    assert 1000 <= host.user(setting("OWNER_NAME")).uid <= 60513
