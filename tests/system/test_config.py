"""The installed system: what the installer was told, and the first owner."""

import json
import re


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


def test_login_screen_lists_the_first_owner(host, setting):
    # SDDM lists the users that enumerate through NSS, within its UID range.
    assert 1000 <= host.user(setting("OWNER_NAME")).uid <= 60513
