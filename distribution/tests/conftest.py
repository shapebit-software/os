"""distribution/'s modules, which import each other by name, for its tests."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
