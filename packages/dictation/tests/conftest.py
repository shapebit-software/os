"""test_dictate.py hears with test_hear.py's made-up microphone and engine,
which it imports by name from this folder."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
