"""Windows follow the workspace's layout: the picture on screen and the
compositor's geometry both change with it. New workspaces have Columns."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

# The layout button shows while the pointer is on the workspace's map, and lies
# half over the map's top edge: here is on both. A right click on the map's
# window would close the window.
LAYOUT_BUTTON = (116, 735)


def geometry():
    clients = sut.hyprctl_json("clients")
    return sorted((c["at"][0], c["at"][1], c["size"][0], c["size"][1]) for c in clients if c["mapped"])


def run(self):
    for _ in range(2):
        sut.as_owner("""hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("nautilus --new-window")'""")
    sut.wait_for(lambda: len(geometry()) == 2, 60)
    assert_screen("layout-columns", 30)
    before = geometry()
    # Columns: side by side, at the same height.
    assert before[0][1] == before[1][1] and before[0][0] != before[1][0], before
    mouse_set(*LAYOUT_BUTTON)
    wait_still_screen(1)
    mouse_click()
    assert_and_click("layout-menu-rows")
    assert_screen("layout-rows", 30)
    after = geometry()
    # Rows: one above the other, at the same place across.
    assert after[0][0] == after[1][0] and after[0][1] != after[1][1], after
    send_key("super-q")
    send_key("super-q")
    sut.wait_for(lambda: geometry() == [], 30)
    assert_screen("desktop", 30)
