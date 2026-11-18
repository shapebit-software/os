"""The recovery key unlocks the volume. The key lives only on the host, so it
reaches the machine through standard input, and never a report."""

import pytest

import machine as machines


def test_recovery_key_unlocks_the_volume(machine):
    if not machine.directory:
        pytest.skip("only the installed disk's recovery key is known")
    key = machines.path("RECOVERY_KEY").read_text()
    done = machine.ssh("cryptsetup open --test-passphrase --key-file=- /dev/disk/by-partlabel/shapebit", input=key)
    assert done.returncode == 0, done.stderr
