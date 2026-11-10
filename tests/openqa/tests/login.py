"""Sign in at the login screen with the password chosen in the installer. The
first sign-in opens Welcome, which this skips: its choices install applications
from the network. Signed in, the home keeps the size that the installer gave it,
and the reserve stays free beside it."""

import json
import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

post_fail_hook = sut.journal_on_failure("login")

GIB = 1024**3


def home_leaves_the_reserve():
    # systemd-homed opens the home at the first sign-in; with settings that do
    # not apply to this machine, it grew the home over the disk, and Welcome's
    # downloads found no space.
    record = json.loads(sut.run(f"homectl inspect -j {sut.OWNER}"))
    assert "diskSize" in record, "the home's size does not apply on every machine"
    assert record.get("rebalanceWeight") in (0, False), "systemd-homed may rebalance the home"
    image = next(iter(record["binding"].values()))["imagePath"]
    size = int(sut.run(f"stat -L -c %s {image}"))
    assert size <= record["diskSize"], f"the home grew to {size} bytes"
    # On a disk of 128 GiB or more, the reserve is at least 64 GiB
    # (docs/Design-Base.md); booting and signing in use some of it.
    if int(get_var("HDDSIZEGB_2")) >= 128:
        free = int(sut.run("findmnt -bno AVAIL /var"))
        assert free >= 56 * GIB, f"only {free} bytes are free beside the home"


def run(self):
    type_password(get_var("OWNER_PASSWORD"))
    send_key("ret")
    assert_screen("welcome-browser", 180)
    sut.wait_for(lambda: sut.run(f"pgrep -u {sut.OWNER} -x Hyprland", check=False) != "")
    sut.wait_for(lambda: sut.as_owner("systemctl --user is-active graphical-session.target", False).strip() == "active")
    assert "State: active" in sut.run(f"homectl inspect {sut.OWNER}")
    home_leaves_the_reserve()
    assert_and_click("welcome-skip-all")
    assert_screen("desktop", 30)


def test_flags(self):
    return {"fatal": 1}
