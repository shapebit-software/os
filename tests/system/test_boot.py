"""The installed system: how it booted, and what it boots from."""

import json
import os
import re

STUB_INFO = "/sys/firmware/efi/efivars/StubInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"
ROOT = "/dev/disk/by-partlabel/shapebit"


def luks_dump(sh):
    return json.loads(sh(f"cryptsetup luksDump --dump-json-metadata {ROOT}"))


def tokens(sh, kind):
    return [token for token in luks_dump(sh)["tokens"].values() if token["type"] == kind]


def status(sh):
    pairs = (line.split(":", 1) for line in sh("cryptsetup status root").splitlines() if ":" in line)
    return {key.strip(): value.strip() for key, value in pairs}


def test_finished_booting_without_failed_units(host, sh):
    host.run("systemctl is-system-running --wait")
    assert sh("systemctl --failed --no-legend") == ""


def test_booted_by_bootc(sh):
    assert json.loads(sh("bootc status --format=json"))["status"]["booted"] is not None


def test_booted_the_image_under_test(sh, setting):
    # Ties the results to the image: what runs is what make built.
    booted = json.loads(sh("bootc status --format=json"))["status"]["booted"]
    assert setting("IMAGE_DIGEST") in json.dumps(booted)


def test_secure_boot_is_enabled(sh):
    assert "SecureBoot enabled" in sh("mokutil --sb-state")


def test_booted_through_shim(sh):
    assert re.search(r"loader:.*/EFI/BOOT/grubx64\.efi", sh("bootctl status 2>/dev/null"), re.I)


def test_images_certificate_is_enrolled(sh):
    assert re.search(r"CN=ShapeBit( Development)?$", sh("mokutil --list-enrolled"), re.M)


def test_booted_by_systemd_boot(sh):
    assert re.search(r"^ +Product: systemd-boot ", sh("bootctl status 2>/dev/null"), re.M)


def test_booted_from_a_uki():
    assert os.path.exists(STUB_INFO)


def test_root_is_sealed_by_a_composefs_digest(host):
    assert re.search(r"(^| )composefs=[0-9a-f]{128}( |$)", host.file("/proc/cmdline").content_string)


def test_serial_console_karg_is_active(host):
    assert "console=ttyS0" in host.file("/proc/cmdline").content_string


def test_root_is_btrfs_on_the_luks2_volume(sh):
    assert sh("findmnt -no FSTYPE /sysroot").strip() == "btrfs"
    assert sh("findmnt -nvo SOURCE /sysroot").strip() == "/dev/mapper/root"
    assert status(sh)["type"] == "LUKS2"


def test_tpm2_key_slot_is_bound_to_pcr_7_and_signed_pcr_11(sh):
    found = tokens(sh, "systemd-tpm2")
    assert len(found) == 1
    assert found[0]["tpm2-pcrs"] == [7] and found[0]["tpm2_pubkey_pcrs"] == [11]


def test_recovery_key_is_enrolled(sh):
    assert len(tokens(sh, "systemd-recovery")) == 1


def test_installation_key_is_gone_no_other_key_slots(sh):
    assert len(luks_dump(sh)["keyslots"]) == 2


def test_unlocked_by_the_tpm(sh):
    log = sh("journalctl -b -o cat -u systemd-cryptsetup@root.service")
    assert "TPM2 token unlocks volume" in log and "falling back" not in log


def test_machine_id_is_saved_not_temporary(host, succeeds):
    machine_id = host.file("/etc/machine-id")
    assert machine_id.size > 0 and "uninitialized" not in machine_id.content_string
    assert not succeeds("findmnt /etc/machine-id")


def test_root_partition_fills_the_disk(sh):
    disk = "/dev/" + sh(f"lsblk -ndo PKNAME {ROOT}").strip()
    free = re.search(r"^Unpartitioned space .*, (\d+) bytes,", sh(f"sfdisk --list-free {disk}"), re.M)
    assert int(free.group(1)) < 2 * 1024 * 1024


def test_luks2_volume_fills_the_root_partition(sh):
    volume = status(sh)
    # cryptsetup reports "offset: N sectors".
    offset, size = (int(volume[key].split()[0]) for key in ("offset", "size"))
    assert offset + size == int(sh(f"blockdev --getsz {ROOT}"))


def test_btrfs_fills_the_luks2_volume(sh):
    device = re.search(r"devid\s+\d+\s+size\s+(\d+)", sh("btrfs filesystem show --raw /sysroot"))
    assert int(device.group(1)) == int(sh("blockdev --getsize64 /dev/mapper/root"))


def test_subvolumes_are_mounted_in_their_places(sh):
    assert sh("findmnt -no FSROOT /sysroot").strip() == "/@base"
    assert sh("findmnt -no FSROOT /var").strip() == "/@machine"
    assert sh("findmnt -no FSROOT /var/home").strip() == "/@people"


def test_recovery_subvolume_exists(sh):
    assert re.search(r" path @recovery$", sh("btrfs subvolume list /sysroot"), re.M)
