"""Sign in at the login screen with the password chosen in the installer. The
first sign-in opens Welcome, which this skips: its choices install applications
from the network."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut


def run(self):
    type_password(get_var("OWNER_PASSWORD"))
    send_key("ret")
    assert_screen("welcome-browser", 180)
    sut.wait_for(lambda: sut.run(f"pgrep -u {sut.OWNER} -x Hyprland", check=False) != "")
    sut.wait_for(lambda: sut.as_owner("systemctl --user is-active graphical-session.target", False).strip() == "active")
    assert "State: active" in sut.run(f"homectl inspect {sut.OWNER}")
    assert_and_click("welcome-skip-all")
    assert_screen("desktop", 30)


def test_flags(self):
    return {"fatal": 1}
