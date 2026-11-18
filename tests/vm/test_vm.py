"""The scripted VMs (vm.sh) and openQA's machine boot the same firmware: with
edk2-ovmf's 2 MB build, the installer's check that the TPM unlocks the new
volume fails, so a firmware that only one of them has hides or causes that."""

import json
import pathlib

HERE = pathlib.Path(__file__).parent


def test_the_vms_boot_the_firmware_that_openqa_boots():
    machine = json.loads((HERE.parent / "openqa/vars.json").read_text())
    script = (HERE / "vm.sh").read_text()
    for firmware in (machine["UEFI_PFLASH_CODE"], machine["UEFI_PFLASH_VARS"]):
        assert firmware in script
        assert "_4M." in firmware
