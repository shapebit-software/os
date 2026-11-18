"""The container image: identity, boot chain, and system services."""

import base64
import glob
import re
import struct

import pytest


def os_release(host):
    lines = host.file("/etc/os-release").content_string.splitlines()
    return dict(line.split("=", 1) for line in lines if "=" in line)


def test_os_release_identifies_shapebit(host):
    assert os_release(host)["ID"] == "shapebit"


def own_packages(sh):
    """ShapeBit's own packages (packages/), by their vendor."""
    lines = sh("rpm -qa --qf '%{NAME} %{VENDOR}\\n'").splitlines()
    return sorted(line.split()[0] for line in lines if line.endswith(" ShapeBit"))


def test_every_feature_is_an_unchanged_package_at_the_images_version(host, sh):
    # packages/: each feature is a package, and shapebit-system requires them all.
    version = os_release(host)["IMAGE_VERSION"].strip('"')
    own = own_packages(sh)
    required = {line.split()[0] for line in sh("rpm -q --requires shapebit-system").splitlines()}
    assert set(own) - {"shapebit-system"} <= required
    assert set(sh("rpm -q --qf '%{VERSION}\\n' " + " ".join(own)).split()) == {version}
    paths = {"/usr/lib/os-release": "shapebit-release",
             "/usr/libexec/os-update": "shapebit-updates", "/usr/share/distrobox/distrobox.conf": "shapebit-apps",
             "/usr/share/plymouth/themes/boot/throbber-0001.png": "shapebit-splash"}
    owners = sh("rpm -qf --qf '%{NAME}\\n' " + " ".join(paths)).split()
    assert owners == list(paths.values())
    # ShapeBit's license is one file that every package of its own code owns;
    # the font is others' work, with its own (packages/package.macros).
    license_owners = sh("rpm -qf --qf '%{NAME}\\n' /usr/share/licenses/shapebit/LICENSE").split()
    assert sorted(license_owners) == [name for name in own if name != "shapebit-font"]
    # shapebit-release stands in for Fedora's identity package.
    assert not host.package("fedora-release-identity-basic").is_installed
    assert host.package("fedora-release-common").is_installed
    # Unchanged since installed; the image's files keep no times.
    sh("rpm -V --nomtime " + " ".join(own))


def test_the_third_party_repositories_ship_turned_off_with_their_keys(host, sh):
    # A record of where packages came from; installed systems never fetch from them.
    for name in ("hyprland", "third-party"):
        path = f"/usr/share/dnf5/repos.d/{name}.repo"
        assert sh(f"rpm -qf --qf '%{{NAME}}' {path}") == "shapebit-repositories"
        text = host.file(path).content_string
        assert "enabled=1" not in text and text.count("enabled=0") == text.count("\n[")
    assert host.file("/usr/share/pki/rpm-gpg/third-party.asc").contains("BEGIN PGP PUBLIC KEY BLOCK")
    enabled = sh("dnf repo list --enabled --quiet")
    assert "hyprland" not in enabled and "shapebit" not in enabled


def test_logos_are_not_fedoras(host):
    # Fedora's logos are its trademarks; generic-logos stands in (images/os/Containerfile).
    assert not host.package("fedora-logos").is_installed
    assert host.package("generic-logos").is_installed


def test_openh264_is_not_redistributed(host):
    # Cisco's patent license covers only the openh264 that Cisco serves itself
    # (images/os/Containerfile).
    assert not host.package("openh264").is_installed
    assert host.package("noopenh264").is_installed


def test_image_version_is_build_time(host):
    # A rolling release: when the build started, in UTC (202610301530), or dev;
    # update tests build dev.next and dev.next2, or the same after a build time.
    version = os_release(host)["IMAGE_VERSION"].strip('"')
    assert re.fullmatch(r"(dev|[0-9]{12})(\.next2?)?", version)


def test_os_release_names_the_commit(host):
    assert re.fullmatch(r"[0-9a-f]{40}", os_release(host)["IMAGE_REVISION"].strip('"'))


def test_os_release_names_no_release_line(host):
    release = os_release(host)
    assert "VERSION_ID" not in release and "VERSION" not in release


def test_dnf_installs_no_weak_deps(sh):
    assert re.search(r"^install_weak_deps\s*=\s*0$", sh("dnf --dump-main-config"), re.M)


def test_dnf_does_not_count_the_computer(sh):
    values = re.findall(r"^countme\s*=\s*(\S+)$", sh("dnf --dump-repo-config='*'"), re.M)
    assert values and set(values) == {"0"}


@pytest.mark.parametrize("unit", ["rpm-ostree-countme.timer", "bootc-fetch-apply-updates.timer"])
def test_base_image_timer_is_masked(host, unit):
    # Counting the computer for Fedora, and updates that restart by themselves.
    assert host.service(unit).is_masked


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


def test_login_screen_stops_when_the_home_cannot_open(host):
    # Before authselect's stack, whose pam_unix would accept the password of a
    # home that systemd-homed could not open (images/os/Containerfile).
    auth = [line.split() for line in host.file("/etc/pam.d/sddm").content_string.splitlines() if line.startswith("auth")]
    homed = auth.index(["auth", "[success=ok", "user_unknown=ignore", "default=die]", "pam_systemd_home.so"])
    assert homed < auth.index(["auth", "substack", "password-auth"])


def test_login_unlocks_the_secret_service(host):
    assert host.file("/usr/lib64/security/pam_oo7.so").exists
    sddm = host.file("/etc/pam.d/sddm").content_string
    assert re.search(r"^-session\s+optional\s+pam_oo7\.so\s+auto_start", sddm, re.M)


def test_no_third_party_repository_left_configured(succeeds):
    assert not succeeds("grep -rqs copr /etc/yum.repos.d")


def test_initramfs_leaves_var_to_fstab(sh):
    conf = sh("lsinitrd /usr/lib/modules/*/initramfs.img -f usr/lib/composefs/setup-root-conf.toml")
    assert re.search(r'^mount = "none"', conf, re.M)


def test_signed_systemd_boot_is_the_boot_packages_signed_from_the_installed_version(host, sh):
    signed = "/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed"
    assert host.file(signed).size > 0
    owners = sh(f"rpm -qf --qf '%{{NAME}}\\n' {signed} /usr/share/secureboot/enroll-this-key.cer").split()
    assert owners == ["shapebit-boot", "shapebit-boot"]
    # shapebit-boot requires the version it was signed from, so a newer
    # systemd-boot-unsigned cannot come without a newly signed copy.
    installed = sh("rpm -q --qf '%{VERSION}-%{RELEASE}' systemd-boot-unsigned")
    assert f"systemd-boot-unsigned = {installed}" in sh("rpm -q --requires shapebit-boot")


def test_uki_carries_a_signed_pcr_policy():
    ukis = glob.glob("/boot/EFI/Linux/*.efi")
    assert ukis, "no UKI"
    with open(ukis[0], "rb") as uki:
        content = uki.read()
    assert b".pcrsig" in content and b".pcrpkey" in content


def test_certificate_to_enroll_is_present(host):
    assert host.file("/usr/share/secureboot/enroll-this-key.cer").size > 0


def pe_section(content, name):
    """The data of the named section of a PE file such as a UKI."""
    pe = struct.unpack_from("<I", content, 0x3C)[0]
    count, optional = struct.unpack_from("<H12xH", content, pe + 6)
    table = pe + 24 + optional
    for offset in range(table, table + 40 * count, 40):
        if content[offset:offset + 8].rstrip(b"\0") == name:
            size, _, raw_size, pointer = struct.unpack_from("<4I", content, offset + 8)
            return content[pointer:pointer + min(size, raw_size)]
    raise AssertionError(f"no {name.decode()} section")


def test_pcr_policy_key_is_not_the_secure_boot_key(host):
    # Separate keys can be replaced separately (release/keys.md). The
    # certificate holds its public key as DER, the UKI's .pcrpkey as PEM.
    with open(glob.glob("/boot/EFI/Linux/*.efi")[0], "rb") as uki:
        pem = pe_section(uki.read(), b".pcrpkey").decode()
    assert "BEGIN PUBLIC KEY" in pem
    pcr_key = base64.b64decode("".join(line for line in pem.splitlines() if not line.startswith("-----")))
    certificate = host.file("/usr/share/secureboot/enroll-this-key.cer").content
    assert len(pcr_key) > 200 and pcr_key not in certificate


def test_shim_and_its_mok_manager_are_present():
    assert glob.glob("/usr/lib/efi/shim/*/EFI/BOOT/BOOTX64.EFI")
    assert glob.glob("/usr/lib/efi/shim/*/EFI/fedora/mmx64.efi")


def test_shims_placement_is_installed(host):
    assert host.file("/usr/libexec/esp-shim").mode & 0o111


def test_no_secure_boot_keys_to_enroll(host):
    # systemd-boot would enroll these on a PC in setup mode, which then refuses shim.
    assert not host.file("/usr/lib/bootc/install/secureboot-keys").exists

