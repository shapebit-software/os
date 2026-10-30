"""The booted installer medium, before it installs. The VM attaches the medium
with the serial "medium" and the target disk with the serial "target"."""

import json
import os
import re

import pytest
from conftest import wait_until

STUB_INFO = "/sys/firmware/efi/efivars/StubInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"


def disks(sh):
    # One JSON object per line.
    return {disk["id"]: disk for disk in map(json.loads, sh("installerctl disks").splitlines())}


def capabilities(sh):
    return json.loads(sh("installerctl capabilities"))


def test_finished_booting_without_other_failed_units(host, sh):
    # Fedora 44's SELinux policy does not yet let systemd-tpm2-setup save its
    # NvPCR anchor credential to the EFI System Partition, so that unit fails on
    # the medium, which is the first system to start on a machine's TPM.
    host.run("systemctl is-system-running --wait")
    failed = [line.split()[0] for line in sh("systemctl --failed --no-legend --plain").splitlines()]
    assert set(failed) <= {"systemd-tpm2-setup.service"}


def test_booted_from_a_uki():
    assert os.path.exists(STUB_INFO)


def test_secure_boot_is_enabled(sh):
    assert "SecureBoot enabled" in sh("mokutil --sb-state")


def test_booted_through_shim(sh):
    assert re.search(r"loader:.*/EFI/BOOT/grubx64\.efi", sh("bootctl status 2>/dev/null"), re.I)


def test_images_certificate_is_enrolled(sh):
    assert re.search(r"CN=ShapeBit( Development)?$", sh("mokutil --list-enrolled"), re.M)


def test_medium_is_sealed_by_a_composefs_digest(host):
    assert re.search(r"(^| )composefs=[0-9a-f]{128}( |$)", host.file("/proc/cmdline").content_string)


def test_payload_is_on_the_medium(host):
    assert host.file("/usr/share/installer/image.tar").size > 0


@pytest.mark.parametrize("unit", ["installer-backend", "installer"])
def test_installer_is_running(host, unit):
    assert host.service(unit).is_running


def test_installer_has_the_screen_no_login_screen(host):
    assert host.service("sddm").is_masked


def test_ui_runs_as_an_unprivileged_user(host):
    # cage starts the UI once installer.service is up, so it may take a moment.
    def users():
        return set(host.run("ps -o user= -C installer").stdout.split())

    assert wait_until(lambda: users() == {"installer"})


def test_backend_finds_uefi_and_a_tpm2(sh):
    found = capabilities(sh)
    assert found["tpm2"] is True and found["uefi"] is True


def test_backend_offers_the_systems_locales(sh):
    assert "en_US.UTF-8" in capabilities(sh)["locales"]


def test_target_disk_is_eligible(sh):
    assert disks(sh)["serial-target"]["eligible"] is True


def test_medium_itself_is_not_eligible(sh):
    assert disks(sh)["serial-medium"]["eligible"] is False


def test_other_users_cannot_reach_the_backend(succeeds):
    assert not succeeds("setpriv --reuid nobody --regid nobody --clear-groups installerctl disks")
