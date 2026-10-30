"""Restart from the system menu (Ctrl+Alt+Delete): the machine comes back to the login screen,
unlocked by the TPM again, and with the same machine ID."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut


def run(self):
    machine_id = sut.run("cat /etc/machine-id")
    boot_id = sut.run("cat /proc/sys/kernel/random/boot_id")
    send_key("ctrl-alt-delete")
    assert_and_click("system-menu-restart")
    # It asks first, since restarting ends the session.
    assert_and_click("system-menu-restart-confirm")
    assert_screen("login-screen", 600)
    sut.wait_for_ssh()
    assert sut.run("cat /proc/sys/kernel/random/boot_id") != boot_id, "the machine did not restart"
    assert sut.run("cat /etc/machine-id") == machine_id
    log = sut.run("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log
