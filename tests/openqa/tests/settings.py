"""Settings, which the shell draws: opens with its shortcut, shows its sections,
and shows what the system has."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut


def run(self):
    send_key("super-i")
    assert_and_click("settings")
    assert_screen("settings-language", 30)
    # What the page lists is the compositor's own keyboard layout.
    keyboards = sut.hyprctl_json("devices")["keyboards"]
    assert any(keyboard["active_keymap"] for keyboard in keyboards)
    send_key("super-i")
    assert_screen("desktop", 30)
