"""The container image: the desktop session, its portals, and its applications."""

import ast

import pytest

PORTALS = "/usr/share/xdg-desktop-portal/shapebit-portals.conf"
PORTAL_DIR = "/usr/share/xdg-desktop-portal/portals"


@pytest.mark.parametrize(
    "command",
    [
        "start-hyprland", "hyprland-dialog", "qs", "grim", "slurp", "wf-recorder", "xdg-user-dir", "wl-copy", "wl-paste",
        "pipewire", "wireplumber", "pipewire-pulse", "upower", "hypridle", "brightnessctl", "clipman",
        "gnome-keyring-daemon", "flatpak", "distrobox",
    ],
)  # fmt: skip
def test_desktop_command_is_installed(host, command):
    assert host.exists(command)


@pytest.mark.parametrize(
    "path",
    [
        "/usr/libexec/desktop/portal",
        "/usr/libexec/desktop/share-picker",
        "/usr/libexec/desktop/connection-agent",
        "/usr/libexec/desktop/app-install",
        "/usr/libexec/desktop/app-catalog",
        "/usr/libexec/desktop/app-remove",
    ],
)
def test_desktop_helper_is_python(host, path):
    helper = host.file(path)
    assert helper.mode & 0o111
    ast.parse(helper.content_string)


@pytest.mark.parametrize(
    "path",
    [
        "/usr/share/desktop/shell/shell.qml",
        f"{PORTAL_DIR}/hyprland.portal",
        f"{PORTAL_DIR}/gnome-keyring.portal",
        "/usr/share/applications/org.gnome.Nautilus.desktop",
        "/usr/share/polkit-1/rules.d/50-os-update.rules",
        "/usr/share/thumbnailers/glycin-image-rs.thumbnailer",
        "/usr/share/thumbnailers/gst-video-thumbnailer.thumbnailer",
    ],
)
def test_desktop_file_is_installed(host, path):
    assert host.file(path).size > 0


def test_compositor_configuration_is_valid(sh):
    # Hyprland refuses to run as root and needs a runtime directory even to
    # verify its configuration.
    sh(
        "setpriv --reuid=nobody --regid=nobody --clear-groups sh -c "
        "'XDG_RUNTIME_DIR=$(mktemp -d) exec Hyprland --verify-config "
        "--config /usr/share/desktop/compositor/hyprland.lua'"
    )


def test_python_scripts_find_gobject(sh):
    sh("""python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio, GLib'""")


def test_portals_are_hyprlands_and_gnome_keyrings(host):
    lines = host.file(PORTALS).content_string.splitlines()
    assert "default=hyprland" in lines
    assert "org.freedesktop.impl.portal.Secret=gnome-keyring" in lines


@pytest.mark.parametrize(
    "interface",
    ["FileChooser", "Screenshot", "AppChooser", "Access", "Account", "Background",
     "DynamicLauncher", "Inhibit", "Notification", "Settings", "Wallpaper"],
)  # fmt: skip
def test_other_portals_are_the_shells(host, interface):
    name = f"org.freedesktop.impl.portal.{interface}"
    assert f"{name}=shell" in host.file(PORTALS).content_string.splitlines()
    assert name in host.file(f"{PORTAL_DIR}/shell.portal").content_string


def test_dbus_starts_the_shells_portal(host):
    service = "/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.shell.service"
    assert "Exec=/usr/libexec/desktop/portal" in host.file(service).content_string.splitlines()


def test_sharing_the_screen_asks_through_the_shell(host, sh):
    # Hyprland's portal reads its configuration from XDG_CONFIG_HOME/hypr only.
    xdph = host.file("/usr/share/desktop/portal/hypr/xdph.conf").content_string
    assert "custom_picker_binary = /usr/libexec/desktop/share-picker" in xdph
    unit = sh("systemctl --user --global cat xdg-desktop-portal-hyprland.service")
    assert "Environment=XDG_CONFIG_HOME=/usr/share/desktop/portal" in unit.splitlines()


def test_distrobox_starts_from_this_fedoras_toolbox_image(host, sh):
    fedora = sh("rpm -E %fedora").strip()
    expected = f'container_image_default="registry.fedoraproject.org/fedora-toolbox:{fedora}"'
    assert expected in host.file("/usr/share/distrobox/distrobox.conf").content_string.splitlines()


def test_flathub_is_a_system_remote(sh):
    # Flatpak adds the remotes in /usr/share/flatpak/remotes.d by itself.
    remotes = sh("flatpak remotes --system --columns=name,url").split()
    assert remotes[:2] == ["flathub", "https://dl.flathub.org/repo/"]


def test_image_viewer_opens_tiff(host):
    mimeapps = host.file("/usr/share/applications/shapebit-mimeapps.list").content_string
    assert "image/tiff=org.gnome.Loupe.desktop" in mimeapps.splitlines()


def test_apps_update_daily(host):
    assert host.file("/usr/lib/systemd/user/timers.target.wants/app-update.timer").is_symlink


def test_system_update_check_is_installed(host):
    assert host.file("/usr/libexec/os-update").mode & 0o111


def test_applications_outside_flatpak_use_the_portals(host):
    assert "GTK_USE_PORTAL=1" in host.file("/usr/lib/environment.d/60-portals.conf").content_string.splitlines()


def test_applications_show_no_window_buttons(sh):
    layout = sh("GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.wm.preferences button-layout")
    assert layout.strip() == "':'"


def test_monospace_font_is_installed(sh):
    assert "JetBrains Mono" in sh("fc-list : family").splitlines()
