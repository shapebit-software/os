"""tests/machine.py, without a machine."""

import json
import pathlib
import re

import pytest

import machine as machines

ROOT = pathlib.Path(__file__).resolve().parents[1]


@pytest.fixture
def build(monkeypatch, tmp_path):
    monkeypatch.setenv("BUILD", str(tmp_path))
    for name in machines.SETTINGS:
        monkeypatch.delenv(name, raising=False)
    return tmp_path


def test_settings_have_defaults_under_build(build):
    assert machines.setting("OWNER_NAME") == "dev"
    assert machines.path("DISK") == build / "disk.raw"


def test_the_environment_overrides_a_setting(build, monkeypatch):
    monkeypatch.setenv("LOCALE", "de_DE.UTF-8")
    assert machines.setting("LOCALE") == "de_DE.UTF-8"


def test_a_build_setting_comes_only_from_make(build, monkeypatch):
    monkeypatch.delenv("MEDIUM", raising=False)
    with pytest.raises(KeyError):
        machines.setting("MEDIUM")


def test_make_passes_every_test_setting_into_the_development_image():
    # images/development/dev.sh passes only the variables that DEV_ENV names.
    makefile = (ROOT / "Makefile").read_text().replace("\\\n", " ")
    names = re.search(r"^TEST_SETTINGS := (.+)$", makefile, re.M)[1].split()
    assert set(names) == set(machines.SETTINGS) | {"IMAGE_DIGEST"}


def test_the_development_key_is_made_once(build):
    key = machines.ssh_key()
    assert key.read_text().startswith("-----BEGIN OPENSSH PRIVATE KEY-----")
    assert machines.ssh_key().read_bytes() == key.read_bytes()


def test_the_owner_password_is_made_once_and_private(build):
    password = machines.owner_password()
    assert password and machines.owner_password() == password
    assert machines.path("OWNER_PASSWORD").stat().st_mode & 0o077 == 0


def test_the_machine_boots_secure_boot_firmware_with_a_tpm_and_the_key_as_a_credential(build):
    machine = machines.Machine(directory=build / "machine", disk=build / "disk.raw")
    args = " ".join(machine.qemu_args())
    assert f"file={machines.FIRMWARE_CODE}" in args and "secure,value=on" in args
    assert "tpm-crb" in args and "serial=target" in args
    assert "ssh.authorized_keys.root=" in args
    assert "serial=medium" not in args


def test_the_medium_boots_first_and_stays_as_built(build):
    machine = machines.Machine(directory=build / "machine", disk=build / "disk.raw", medium=build / "installer.img")
    args = " ".join(machine.qemu_args())
    assert "snapshot=on" in args and "serial=medium,bootindex=1" in args


def test_ssh_shares_one_connection_unless_the_machine_restarts_on_its_own(build):
    assert "ControlMaster=auto" in machines.Machine().ssh_options()
    assert "ControlMaster=auto" not in machines.Machine(multiplex=False).ssh_options()


def test_a_stale_pid_file_stops_nothing(build):
    machine = machines.Machine(directory=build, disk=build / "disk.raw", multiplex=False)
    (build / "vm.pid").write_text("1\n")
    machine.stop()


def test_a_record_value_comes_from_the_file_beside(build):
    (build / "installer.img.json").write_text(json.dumps({"image_digest": "sha256:abc"}))
    assert machines.recorded(build / "installer.img", "image_digest") == "sha256:abc"


def test_wait_until_returns_the_last_value(monkeypatch):
    values = iter([0, 0, 3])
    assert machines.wait_until(lambda: next(values), interval=0) == 3
    assert machines.wait_until(lambda: None, timeout=0) is None
