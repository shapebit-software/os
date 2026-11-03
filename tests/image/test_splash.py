"""The container image: the boot splash, and how the screen passes from it to
the login screen without a black frame."""

import glob
import re
import tomllib

THEME = "/usr/share/plymouth/themes/boot"


def kargs():
    return [karg for path in sorted(glob.glob("/usr/lib/bootc/kargs.d/*.toml"))
            for karg in tomllib.load(open(path, "rb")).get("kargs", [])]


def test_boot_shows_the_splash_not_messages():
    assert {"quiet", "splash"} <= set(kargs())


def test_console_background_is_the_splash_color():
    assert {"vt.default_red=0x1f", "vt.default_grn=0x1a", "vt.default_blu=0x3c"} <= set(kargs())


def test_splash_theme_is_the_default(sh):
    assert sh("plymouth-set-default-theme").strip() == "boot"


def test_splash_theme_has_the_logo_and_the_spinner(host):
    for image in ["watermark.png", "throbber-0001.png", "entry.png", "lock.png", "bullet.png"]:
        assert host.file(f"{THEME}/{image}").size > 0, image


def test_initramfs_carries_the_splash(sh):
    files = sh("lsinitrd /usr/lib/modules/*/initramfs.img")
    assert "usr/bin/plymouthd" in files
    assert f"{THEME[1:]}/boot.plymouth" in files
    assert f"{THEME[1:]}/watermark.png" in files


def test_login_screen_takes_the_screen_from_the_splash(sh):
    # plymouth-quit.service would clear the screen before the greeter draws.
    assert "plymouth-quit.service" in sh("systemctl show -p Conflicts --value sddm.service").split()
    assert "quit --retain-splash" in sh("systemctl show -p ExecStartPost --value sddm.service")


def test_desktop_starts_on_the_splash_color(host):
    compositor = host.file("/usr/share/desktop/compositor/hyprland.lua").content_string
    assert re.search(r'background_color\s*=\s*"rgb\(1f1a3c\)"', compositor)
    assert 'night: "#1f1a3c"' in host.file("/usr/share/sddm/themes/login/Theme.qml").content_string
