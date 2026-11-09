"""The assistant's sidebar reserves its width on a wide screen: a window
retiles beside it when it opens, and takes the room back when it closes."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

SIDEBAR = "qs ipc --pid $(pgrep -x qs | head -n 1) call assistant sidebar"
# The sidebar's width, as AssistantSidebar.qml sets it, without the gap.
WIDTH = 340


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
    sut.as_owner(SIDEBAR)
    sut.wait_for(lambda: right_edge() <= alone - WIDTH, 15)
    sut.as_owner(SIDEBAR)
    sut.wait_for(lambda: right_edge() == alone, 15)
    send_key("super-q")
    sut.wait_for(lambda: not windows(), 30)
