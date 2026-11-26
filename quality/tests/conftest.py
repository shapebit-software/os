"""quality/'s modules, such as machine.py, which its tests import by name."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
