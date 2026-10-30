"""The container image: identity, boot chain, and system services."""

import glob
import re

import pytest


def os_release(host):
    lines = host.file("/etc/os-release").content_string.splitlines()
    return dict(line.split("=", 1) for line in lines if "=" in line)


def test_os_release_identifies_shapebit(host):
    assert os_release(host)["ID"] == "shapebit"


def test_image_version_is_build_date_and_commit(host):
    # A rolling release: the build date and commit (20261030_e0920a), or dev;
    # update tests build dev.next and dev.next2.
    version = os_release(host)["IMAGE_VERSION"].strip('"')
    assert re.fullmatch(r"dev(\.next2?)?|[0-9]{8}_[0-9a-f]{6}", version)


def test_os_release_names_the_commit(host):
    assert re.fullmatch(r"[0-9a-f]{40}", os_release(host)["IMAGE_REVISION"].strip('"'))


def test_os_release_names_no_release_line(host):
    release = os_release(host)
    assert "VERSION_ID" not in release and "VERSION" not in release


def test_dnf_installs_no_weak_deps(sh):
    assert re.search(r"^install_weak_deps\s*=\s*0$", sh("dnf --dump-main-config"), re.M)


def test_default_target_is_graphical(sh):
    assert sh("systemctl get-default").strip() == "graphical.target"


@pytest.mark.parametrize(
    "unit",
    ["sddm", "sshd", "NetworkManager", "systemd-homed", "power-profiles-daemon", "os-update.timer"],
)
def test_unit_is_enabled(host, unit):
    assert host.service(unit).is_enabled


def test_no_first_boot_prompt_the_installer_creates_the_owner(host):
    assert not host.service("systemd-homed-firstboot").is_enabled


def test_pam_uses_homed(host):
    assert host.file("/etc/pam.d/system-auth").contains("pam_systemd_home")


def test_login_unlocks_the_secret_service(host):
    assert host.file("/usr/lib64/security/pam_gnome_keyring.so").exists


def test_no_third_party_repository_left_configured(succeeds):
    assert not succeeds("grep -rqs copr /etc/yum.repos.d")


def test_initramfs_leaves_var_to_fstab(sh):
    conf = sh("lsinitrd /usr/lib/modules/*/initramfs.img -f usr/lib/composefs/setup-root-conf.toml")
    assert re.search(r'^mount = "none"', conf, re.M)


def test_signed_systemd_boot_is_present(host):
    assert host.file("/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed").size > 0


def test_uki_carries_a_signed_pcr_policy():
    ukis = glob.glob("/boot/EFI/Linux/*.efi")
    assert ukis, "no UKI"
    with open(ukis[0], "rb") as uki:
        content = uki.read()
    assert b".pcrsig" in content and b".pcrpkey" in content


def test_certificate_to_enroll_is_present(host):
    assert host.file("/usr/share/secureboot/enroll-this-key.cer").size > 0


def test_shim_and_its_mok_manager_are_present():
    assert glob.glob("/usr/lib/efi/shim/*/EFI/BOOT/BOOTX64.EFI")
    assert glob.glob("/usr/lib/efi/shim/*/EFI/fedora/mmx64.efi")


def test_shims_placement_is_installed(host):
    assert host.file("/usr/libexec/esp-shim").mode & 0o111


def test_no_secure_boot_keys_to_enroll(host):
    # systemd-boot would enroll these on a PC in setup mode, which then refuses shim.
    assert not host.file("/usr/lib/bootc/install/secureboot-keys").exists


def test_tmt_can_reach_guests(sh):
    # Otherwise tmt builds a derived image and tests that instead.
    sh("rsync --version")
