"""Update the installed system to the candidate and restart into it, as an
existing system does. The candidate's package is private, so the machine gets
the candidate as an OCI layout, copied over SSH, rather than from the registry;
it is kept, so that os-update finds nothing newer. The modules that follow test
the candidate."""

import json
import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

post_fail_hook = sut.journal_on_failure("update")

LAYOUT = "/var/tmp/candidate"


def run(self):
    sut.copy_dir("/candidate", LAYOUT)
    sut.run(f"bootc switch --quiet --transport oci {LAYOUT}")
    boot_id = sut.run("cat /proc/sys/kernel/random/boot_id")
    sut.run("systemctl reboot", check=False)
    # The login screen is still up until the machine goes down.
    assert_screen("boot-splash", 300)
    assert_screen("login-screen", 600)
    sut.wait_for_ssh()
    assert sut.run("cat /proc/sys/kernel/random/boot_id") != boot_id, "the machine did not restart"
    status = json.loads(sut.run("bootc status --format=json"))
    assert get_var("UPDATE_DIGEST") in json.dumps(status["status"]["booted"]), "not the candidate"
    assert get_var("IMAGE_DIGEST") in json.dumps(status["status"]["rollback"]), "the installed system is gone"
    log = sut.run("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log


def test_flags(self):
    return {"fatal": 1}
