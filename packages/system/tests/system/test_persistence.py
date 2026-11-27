"""What survives a reboot, and what does not."""

import pytest

pytestmark = pytest.mark.system_installed(update=False)


SURVIVES = ["/etc/persistence-check", "/var/lib/persistence-check", "/var/home/persistence-check"]
FORGOTTEN = "/run/persistence-check"
LEFT = "left before the reboot"


def test_system_files_are_read_only(host):
    assert host.run("touch /usr/persistence-check").rc != 0


@pytest.fixture(scope="module")
def rebooted(machine, sh):
    """State left behind, then a reboot; the machine ID from before it."""
    for path in [*SURVIVES, FORGOTTEN]:
        sh(f"echo '{LEFT}' >{path}")
    machine_id = sh("cat /etc/machine-id")
    machine.reboot()
    yield machine_id
    sh("rm -f " + " ".join(SURVIVES))


@pytest.mark.parametrize("path", SURVIVES)
def test_machine_state_survives(rebooted, host, path):
    assert host.file(path).content_string == LEFT + "\n"


def test_runtime_state_is_gone(rebooted, host):
    assert not host.file(FORGOTTEN).exists


def test_machine_id_is_the_same(rebooted, sh):
    assert sh("cat /etc/machine-id") == rebooted


def test_tpm_unlocks_again_on_the_next_boot(rebooted, sh):
    log = sh("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log


def test_system_comes_up_again_without_failed_units(rebooted, host, sh):
    host.run("systemctl is-system-running --wait")
    assert sh("systemctl --failed --no-legend") == ""
