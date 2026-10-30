"""The one check that needs a host-side secret: the recovery key lives only on
the host, so it reaches the machine through standard input, and never a report."""

import os
import subprocess


def test_recovery_key_unlocks_the_volume():
    with open(os.environ["RECOVERY_KEY"], "rb") as key:
        result = subprocess.run(
            ["scripts/ssh.sh", "cryptsetup open --test-passphrase --key-file=- /dev/disk/by-partlabel/shapebit"],
            stdin=key,
            capture_output=True,
            text=True,
        )
    assert result.returncode == 0, result.stderr
