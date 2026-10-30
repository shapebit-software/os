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
