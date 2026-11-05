"""installer/data/installer.service, read as a file."""

import pathlib

UNIT = pathlib.Path(__file__).parents[2] / "installer" / "data" / "installer.service"


def values(key):
    """All the words of every `key=` line; systemd joins repeated list keys."""
    return {word for line in UNIT.read_text().splitlines() if line.startswith(f"{key}=")
            for word in line.split("=", 1)[1].split()}


def test_installer_takes_tty1_from_either_console():
    # Fedora 45 starts kmscon on tty1 instead of agetty. While the installer
    # did not stop it, kmscon kept the display device and cage could not start.
    consoles = {"getty@tty1.service", "kmsconvt@tty1.service"}
    assert consoles <= values("Conflicts")
    assert consoles <= values("After")
