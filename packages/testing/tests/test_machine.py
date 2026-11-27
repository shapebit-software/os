"""machine.py, without a machine."""

import json
import os
import pathlib
import re
import subprocess

import pytest
from testing import machine as machines

pytestmark = pytest.mark.integration


ROOT = pathlib.Path(__file__).resolve().parents[3]


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


def test_make_passes_every_setting_into_the_development_image():
    # development/dev.sh passes only the variables that DEV_ENV names;
    # ENGINE becomes the client of the host's engine there.
    makefile = (ROOT / "Makefile").read_text()
    names = set(subprocess.run(["make", "-s", "--no-print-directory", "--eval", "dev-env: ; @echo $(DEV_ENV)", "dev-env"],
                               cwd=ROOT, env=os.environ | {"IN_DEV_IMAGE": "1"}, check=True,
                               capture_output=True, text=True).stdout.split())
    build = set(re.findall(r"^([A-Z_0-9]+) *\?=", makefile, re.M)) - {"ENGINE"}
    assert build <= names, build - names
    assert set(machines.SETTINGS) | {"IMAGE_DIGEST", "GUEST"} <= names


def test_the_development_key_is_made_once(build):
    key = machines.ssh_key()
    assert key.read_text().startswith("-----BEGIN OPENSSH PRIVATE KEY-----")
    assert machines.ssh_key().read_bytes() == key.read_bytes()


def test_the_owner_password_is_the_easy_one_written_once_and_private(build):
    assert machines.owner_password() == machines.DEVELOPMENT_PASSWORD
    assert machines.path("OWNER_PASSWORD").stat().st_mode & 0o077 == 0


def test_an_owner_password_already_written_stays(build):
    password = machines.path("OWNER_PASSWORD")
    password.parent.mkdir(parents=True, exist_ok=True)
    password.write_text("another one")
    assert machines.owner_password() == "another one"


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


def test_only_a_medium_of_this_commit_is_checked(build, monkeypatch):
    # The update test installs the stable medium, which an older commit built.
    monkeypatch.setenv("IMAGE_REVISION", "abc")
    (build / "installer.img.json").write_text(json.dumps({"revision": "abc"}))
    assert machines.checks_medium(build / "installer.img")
    (build / "installer.img.json").write_text(json.dumps({"revision": "def"}))
    assert not machines.checks_medium(build / "installer.img")


def test_wait_until_returns_the_last_value(monkeypatch):
    values = iter([0, 0, 3])
    assert machines.wait_until(lambda: next(values), interval=0) == 3
    assert machines.wait_until(lambda: None, timeout=0) is None


def usb_device(root, name, vendor, product, devnum, interfaces, product_name="Device", openable=True):
    """A USB device in ROOT's sysfs, with INTERFACES as class, subclass, and
    protocol, and its node in ROOT's /dev, which may open or not."""
    device = root / "sys/bus/usb/devices" / name
    device.mkdir(parents=True)
    for key, value in (("idVendor", vendor), ("idProduct", product), ("busnum", "1"), ("devnum", str(devnum)),
                       ("product", product_name)):
        (device / key).write_text(f"{value}\n")
    for number, code in enumerate(interfaces):
        interface = device / f"{name}:1.{number}"
        interface.mkdir()
        for key, value in zip(("bInterfaceClass", "bInterfaceSubClass", "bInterfaceProtocol"),
                              (code[0:2], code[2:4], code[4:6])):
            (interface / key).write_text(f"{value}\n")
    node = root / f"dev/bus/usb/001/{devnum:03}"
    node.parent.mkdir(parents=True, exist_ok=True)
    node.write_text("")
    node.chmod(0o600 if openable else 0o400)


def test_the_vm_borrows_cameras_by_their_class_unless_told_otherwise(tmp_path, monkeypatch):
    usb_device(tmp_path, "1-1", "05c8", "0b10", 2, ["0e0101", "0e0201"])
    usb_device(tmp_path, "1-2", "0bda", "b85d", 3, ["e00101"])
    usb_device(tmp_path, "1-3", "046d", "c52b", 4, ["030101"])
    monkeypatch.delenv("DEVICES", raising=False)
    assert machines.usb_devices(tmp_path) == {
        "camera-05c8-0b10": {"driver": "usb-host", "bus": "usb.0", "vendorid": 0x05c8, "productid": 0x0b10}}
    monkeypatch.setenv("DEVICES", "camera bluetooth")
    assert set(machines.usb_devices(tmp_path)) == {"camera-05c8-0b10", "bluetooth-0bda-b85d"}
    monkeypatch.setenv("DEVICES", "")
    assert machines.usb_devices(tmp_path) == {}


def test_a_device_this_computer_does_not_let_open_is_not_lent(tmp_path, monkeypatch, capsys):
    usb_device(tmp_path, "1-1", "05c8", "0b10", 2, ["0e0101"], "HP Camera", openable=False)
    monkeypatch.delenv("DEVICES", raising=False)
    assert machines.usb_devices(tmp_path) == {}
    assert "Not lending HP Camera (camera)" in capsys.readouterr().err


def test_an_unknown_kind_of_device_is_refused(tmp_path, monkeypatch):
    monkeypatch.setenv("DEVICES", "printer")
    with pytest.raises(SystemExit):
        machines.usb_devices(tmp_path)
