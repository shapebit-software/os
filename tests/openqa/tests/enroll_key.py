"""A new PC's first boot of the medium: shim refuses systemd-boot and opens its
MOK manager; there, enroll the image's certificate from the medium. The screens
are also on the serial console, which is what this waits for."""

import sys
import time

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut


def step(text, *keys):
    wait_serial(text, 300)
    # The console shows a screen before the screen takes keys, and a key sent
    # too early is lost: a lost "down" on the last question answers No.
    time.sleep(1)
    for key in keys:
        send_key(key)
        time.sleep(1)


def run(self):
    step("Verification failed", "ret")
    step("Press any key", "ret")
    step("Perform MOK management", "down", "ret")
    # The partition, then the certificate: the last entry, after EFI/ and loader/.
    step("Select Key", "ret")
    step("enroll-this-key.cer", "down", "down", "ret")
    step("View key 0", "down", "ret")
    step("Enroll the key", "down", "ret")
    step("Reboot", "ret")
    # The medium boots only now, and its firmware agrees.
    sut.wait_for_ssh()
    assert "ShapeBit" in sut.run("mokutil --list-enrolled")


def test_flags(self):
    return {"fatal": 1}
