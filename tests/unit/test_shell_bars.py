"""The bars' layout logic of the shell (desktop/shell/services/bars.js), by its
QML test tests/unit/shell/tst_bars.qml, which qmltestrunner runs offscreen."""

import pathlib
import shutil
import subprocess

TEST = pathlib.Path(__file__).parent / "shell" / "tst_bars.qml"


def test_bars_layout():
    # Fedora names Qt 6's runner with a suffix; qt6-qtdeclarative-devel has it.
    runner = shutil.which("qmltestrunner-qt6") or shutil.which("qmltestrunner")
    assert runner, "qmltestrunner is missing: install qt6-qtdeclarative-devel"
    result = subprocess.run([runner, "-platform", "offscreen", "-input", str(TEST)],
                            capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout + result.stderr
