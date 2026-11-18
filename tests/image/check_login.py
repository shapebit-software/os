"""The container image: the login screen."""

import os


def login_conf(host):
    return host.file("/usr/lib/sddm/sddm.conf.d/10-login.conf").content_string.splitlines()


def test_login_screen_uses_the_login_theme(host):
    assert "Current=login" in login_conf(host)
    assert host.file("/usr/share/sddm/themes/login/Main.qml").size > 0


def test_login_screen_lists_homed_users(host):
    assert "MaximumUid=60513" in login_conf(host)


def test_login_themes_font_is_installed(sh):
    assert "Instrument Sans" in sh("fc-list : family").splitlines()


def test_desktop_session_is_installed(host):
    assert "TryExec=uwsm" in host.file("/usr/share/wayland-sessions/desktop.desktop").content_string


def test_login_screen_offers_only_the_desktop_session():
    assert os.listdir("/usr/share/wayland-sessions") == ["desktop.desktop"]
    assert not os.path.isdir("/usr/share/xsessions") or not os.listdir("/usr/share/xsessions")


def test_lock_screen_has_the_login_screens_backdrop(host):
    # Both draw the one in Colors, the module of the system's colors, which
    # Qt finds in its own folder of QML modules.
    assert host.file("/usr/lib64/qt6/qml/Colors/Backdrop.qml").is_file
    assert "Backdrop 1.0 Backdrop.qml" in host.file("/usr/lib64/qt6/qml/Colors/qmldir").content_string
    for screen in ["/usr/share/sddm/themes/login/Main.qml", "/usr/share/desktop/shell/lock/LockSurface.qml"]:
        assert "import Colors" in host.file(screen).content_string, screen


def test_login_screen_runs_in_hyprland(host):
    # Weston, SDDM's usual compositor, shows the greeter without a cursor.
    assert "CompositorCommand=start-hyprland -- --config /usr/lib/sddm/compositor.lua" in login_conf(host)


def test_login_screens_compositor_configuration_is_valid(sh):
    # Hyprland refuses to run as root and needs a runtime directory even to
    # verify its configuration.
    sh(
        "setpriv --reuid=nobody --regid=nobody --clear-groups sh -c "
        "'XDG_RUNTIME_DIR=$(mktemp -d) exec Hyprland --verify-config "
        "--config /usr/lib/sddm/compositor.lua'"
    )
