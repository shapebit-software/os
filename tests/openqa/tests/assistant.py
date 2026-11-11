"""The assistant's three ways to show: a tap on Super opens its bubbles and closes
them; its panel lies over the windows, and docked it reserves its width, so a
window retiles beside it and takes the room back when the panel hides; a tap
keeps a docked panel, and brings back what was open last. Super held is no tap:
it would listen, and says why it cannot, as no model is downloaded here.
tests/unit covers the rest: the rules (shell/tst_assistant.qml), hearing
(test_dictate.py), and the requests (test_assistant.py)."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

post_fail_hook = sut.journal_on_failure("assistant")

CALL = "qs ipc --pid $(pgrep -x qs | head -n 1) call assistant "
# The panel's width until changed (shell/services/assistant.js), without the gap.
WIDTH = 340


def mode():
    return sut.as_owner(CALL + "mode").strip()


def windows():
    return [c for c in sut.hyprctl_json("clients") if c["mapped"]]


def right_edge():
    (window,) = windows()
    return window["at"][0] + window["size"][0]


def run(self):
    sut.as_owner("""hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("nautilus --new-window")'""")
    sut.wait_for(lambda: len(windows()) == 1, 60)
    wait_still_screen(1)
    alone = right_edge()
    assert mode() == ""

    # A tap: the bubbles, and away again.
    send_key("super")
    sut.wait_for(lambda: mode() == "bubbles", 15)
    assert right_edge() == alone
    send_key("super")
    sut.wait_for(lambda: mode() == "", 15)

    # The panel lies over the windows; docked, they make room for it.
    sut.as_owner(CALL + "panel")
    sut.wait_for(lambda: mode() == "panel", 15)
    wait_still_screen(1)
    assert right_edge() == alone
    sut.as_owner(CALL + "dock true")
    sut.wait_for(lambda: mode() == "docked", 15)
    sut.wait_for(lambda: right_edge() <= alone - WIDTH, 15)

    # A tap keeps the docked panel; hidden, the window has the room again, and
    # a tap brings back what was open last.
    send_key("super")
    wait_still_screen(1)
    assert mode() == "docked"
    sut.as_owner(CALL + "hide")
    sut.wait_for(lambda: mode() == "" and right_edge() == alone, 15)
    send_key("super")
    sut.wait_for(lambda: mode() == "docked", 15)
    sut.wait_for(lambda: right_edge() <= alone - WIDTH, 15)
    sut.as_owner(CALL + "dock false")
    sut.wait_for(lambda: right_edge() == alone, 15)
    sut.as_owner(CALL + "hide")
    sut.wait_for(lambda: mode() == "", 15)

    # Held, Super is no tap: it would listen, and nothing opens.
    hold_key("super")
    sut.wait_for(lambda: sut.as_owner(CALL + "notice").strip() == "Needs a download", 15)
    release_key("super")
    wait_still_screen(1)
    assert mode() == ""

    send_key("super-q")
    sut.wait_for(lambda: not windows(), 30)
