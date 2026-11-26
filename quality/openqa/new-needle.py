#!/usr/bin/env python3
"""Make a needle from a screenshot in a run's testresults: the picture, and a
JSON naming its tag and the areas that must match. Choose areas that show what
the screen means, such as a heading, and nothing that changes, such as the time.

Usage: new-needle.py SCREENSHOT TAG X Y WIDTH HEIGHT [X Y WIDTH HEIGHT]... [--click]
       --click makes the middle of the last area where assert_and_click clicks.
"""

import json
import pathlib
import shutil
import sys

args = sys.argv[1:]
click = "--click" in args
if click:
    args.remove("--click")
if len(args) < 6 or (len(args) - 2) % 4:
    sys.exit(__doc__)
screenshot, tag, *numbers = args
needles = pathlib.Path(__file__).parent / "needles"
areas = []
for x, y, width, height in zip(*[map(int, numbers)] * 4):
    areas.append({"xpos": x, "ypos": y, "width": width, "height": height, "type": "match"})
if click:
    areas[-1]["click_point"] = {"xpos": areas[-1]["width"] // 2, "ypos": areas[-1]["height"] // 2}
shutil.copyfile(screenshot, needles / f"{tag}.png")
(needles / f"{tag}.json").write_text(json.dumps({"area": areas, "properties": [], "tags": [tag]}, indent=2) + "\n")
