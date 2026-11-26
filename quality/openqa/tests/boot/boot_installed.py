"""The first boot of the installed system: the splash shows the logo, not boot
messages; the TPM unlocks it with no prompt; and the login screen appears.
The update flow boots the stable release, whose screens its own release
tested: there, only the state underneath counts."""

import json
import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

post_fail_hook = sut.journal_on_failure("boot_installed")


def run(self):
    # Plymouth shows only messages, without the logo, if a serial console makes
    # it fall back to text (/usr/lib/bootc/kargs.d/30-splash.toml).
    if get_var("FLOW") == "update":
        sut.wait_for_ssh(600)
        sut.wait_for(lambda: sut.run("systemctl is-active sddm", check=False).strip() == "active", 120)
    else:
        assert_screen("boot-splash", 300)
        assert_screen("login-screen", 600)
        sut.wait_for_ssh()
    status = json.loads(sut.run("bootc status --format=json"))
    assert get_var("IMAGE_DIGEST") in json.dumps(status["status"]["booted"]), "not the image under test"
    assert "SecureBoot enabled" in sut.run("mokutil --sb-state")
    log = sut.run("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log
    assert sut.run("findmnt -nvo SOURCE /sysroot").strip() == "/dev/mapper/root"


def test_flags(self):
    return {"fatal": 1}
