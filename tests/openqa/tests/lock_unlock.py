"""The lock screen covers the session, refuses a wrong password, and opens with
the right one."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

# The shell's own answer; --pid selects it with no display to match.
IS_LOCKED = "qs ipc --pid $(pgrep -x qs | head -n 1) call lock isLocked"


def locked():
    return sut.as_owner(IS_LOCKED).strip() == "true"


def run(self):
    assert not locked()
    send_key("super-l")
    assert_screen("lock-screen", 30)
    sut.wait_for(locked, 15)
    type_string("notthepassword")
    send_key("ret")
    assert_screen("lock-screen-refused", 30)
    assert locked(), "a wrong password opened the session"
    type_password(get_var("OWNER_PASSWORD"))
    send_key("ret")
    assert_screen("desktop", 30)
    sut.wait_for(lambda: not locked(), 15)
