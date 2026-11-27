"""The shell loaded every file of its own and of the features it shows
(services/Features.qml), without an error; and Settings, which it draws:
opens with its shortcut, shows its sections, and shows what the system has."""

import re
import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

post_fail_hook = sut.journal_on_failure("settings")

# What Quickshell logs for QML that does not work: a name that is not there, a
# type or module that is not, a value of the wrong type; and a feature that
# did not load.
QML_ERROR = re.compile(r"ReferenceError|TypeError|is not a type|is not installed|Cannot assign|Features: ")


def shell_loaded_without_errors():
    log = sut.as_owner("journalctl --user -b -u shell.service --no-pager -o cat", False)
    errors = [line for line in log.splitlines() if QML_ERROR.search(line)]
    assert not errors, "the shell logged QML errors:\n" + "\n".join(errors)


def run(self):
    shell_loaded_without_errors()
    send_key("super-i")
    assert_and_click("settings")
    assert_screen("settings-language", 30)
    # What the page lists is the compositor's own keyboard layout.
    keyboards = sut.hyprctl_json("devices")["keyboards"]
    assert any(keyboard["active_keymap"] for keyboard in keyboards)
    send_key("super-i")
    assert_screen("desktop", 30)
