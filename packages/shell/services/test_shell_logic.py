"""The shell's logic that needs no desktop (packages/shell/services/*.js): the
bars' layout, the assistant's modes and keys, the notifications' rules, and the
background apps' icons, by
their QML tests beside them (tst_*.qml), which qmltestrunner runs offscreen."""

import pathlib
import shutil
import subprocess

import pytest

TESTS = pathlib.Path(__file__).parent


@pytest.mark.parametrize("test", ["tst_assistant.qml", "tst_bars.qml", "tst_notifications.qml", "tst_tray.qml"])
def test_shell_logic(test, tmp_path):
    # Fedora names Qt 6's runner with a suffix; qt6-qtdeclarative-devel has it.
    runner = shutil.which("qmltestrunner-qt6") or shutil.which("qmltestrunner")
    assert runner, "qmltestrunner is missing: install qt6-qtdeclarative-devel"
    # Run from a copy with the scripts: beside them, the folder's qmldir would
    # import the services, which need Quickshell, and Quickshell loads only in
    # its own program.
    for script in TESTS.glob("*.js"):
        shutil.copy(script, tmp_path)
    shutil.copy(TESTS / test, tmp_path)
    result = subprocess.run([runner, "-platform", "offscreen", "-input", str(tmp_path / test)],
                            capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stdout + result.stderr
