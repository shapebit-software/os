"""The recovery key unlocks the volume. The key lives only on the host, so it
reaches the machine through standard input, and never a report."""

import pytest

pytestmark = pytest.mark.system_installed


def test_recovery_key_unlocks_the_volume(machine, recovery_key):
    done = machine.ssh("cryptsetup open --test-passphrase --key-file=- /dev/disk/by-partlabel/shapebit",
                       input=recovery_key)
    assert done.returncode == 0, done.stderr
