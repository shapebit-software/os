"""What survives a reboot, and what does not. tmt's data directory, which also
survives, carries what the first stage saw to the second."""

import os
import pathlib

import pytest

SURVIVES = ["/etc/persistence-check", "/var/lib/persistence-check", "/var/home/persistence-check"]
FORGOTTEN = "/run/persistence-check"
MACHINE_ID = pathlib.Path(os.environ.get("TMT_TEST_DATA", "/tmp")) / "machine-id"


@pytest.mark.before_reboot
def test_leave_state_for_the_next_boot(host):
    for path in [*SURVIVES, FORGOTTEN]:
        pathlib.Path(path).write_text("left before the reboot\n")
    MACHINE_ID.write_text(host.file("/etc/machine-id").content_string)


@pytest.mark.before_reboot
def test_system_files_are_read_only(host):
    assert host.run("touch /usr/persistence-check").rc != 0


@pytest.mark.after_reboot
@pytest.mark.parametrize("path", SURVIVES)
def test_machine_state_survives(path):
    assert pathlib.Path(path).read_text() == "left before the reboot\n"
    pathlib.Path(path).unlink()


@pytest.mark.after_reboot
def test_runtime_state_is_gone():
    assert not pathlib.Path(FORGOTTEN).exists()


@pytest.mark.after_reboot
def test_machine_id_is_the_same(host):
    assert host.file("/etc/machine-id").content_string == MACHINE_ID.read_text()


@pytest.mark.after_reboot
def test_tpm_unlocks_again_on_the_next_boot(sh):
    log = sh("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log


@pytest.mark.after_reboot
def test_system_comes_up_again_without_failed_units(host, sh):
    host.run("systemctl is-system-running --wait")
    assert sh("systemctl --failed --no-legend") == ""
