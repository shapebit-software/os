"""The first boot of the installed system: the TPM unlocks it with no prompt, and
the login screen appears."""

import json
import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut


def run(self):
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
