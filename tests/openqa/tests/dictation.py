"""The dictation button says when there is no microphone. With one, it listens
and shows it; a right click discards, and a click stops. So does its shortcut,
tapped or held. The microphone here is silent, so what is written down is not
checked: tests/image hears speech, and tests/unit covers where the text goes."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

# The small button under capture, on the dock.
DICTATE_BUTTON = (1192, 776)
CALL = "qs ipc --pid $(pgrep -x qs | head -n 1) call dictation "
MICROPHONE = (
    "pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=silent-microphone "
    "media.class=Audio/Source/Virtual object.linger=true audio.position=[MONO] }'"
)


def state():
    return sut.as_owner(CALL + "state").strip()


def notice():
    return sut.as_owner(CALL + "notice").strip()


def run(self):
    assert state() == "idle"
    mouse_set(*DICTATE_BUTTON)
    wait_still_screen(1)
    mouse_click()
    sut.wait_for(lambda: notice() == "No microphone", 15)
    sut.wait_for(lambda: notice() == "", 15)
    assert state() == "idle"

    sut.as_owner(MICROPHONE)
    sut.wait_for(lambda: "silent-microphone" in sut.as_owner("pw-cli ls Node"), 15)
    mouse_click()
    sut.wait_for(lambda: state() == "listening", 15)
    assert_screen("dictating", 30)
    mouse_click("right")
    sut.wait_for(lambda: state() == "idle", 15)

    mouse_click()
    sut.wait_for(lambda: state() == "listening", 15)
    wait_still_screen(2, 5)
    mouse_click()
    sut.wait_for(lambda: state() != "listening", 15)
    # Silence delivers nothing, and is no failure.
    sut.wait_for(lambda: state() == "idle", 120)
    sut.wait_for(lambda: notice() == "", 15)
    mouse_hide()

    # The shortcut: a tap starts and another stops; held, it stops when let go.
    send_key("super-d")
    sut.wait_for(lambda: state() == "listening", 15)
    send_key("super-d")
    sut.wait_for(lambda: state() != "listening", 15)
    sut.wait_for(lambda: state() == "idle", 120)

    hold_key("super-d")
    sut.wait_for(lambda: state() == "listening", 15)
    release_key("super-d")
    sut.wait_for(lambda: state() != "listening", 15)
    sut.wait_for(lambda: state() == "idle", 120)
