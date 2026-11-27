"""The online models' tests start the assistant as test_assistant.py does, with
its made-up model (Setup), which they import by name from this folder."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
