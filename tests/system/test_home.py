"""The installed system: a throwaway systemd-homed user shows that homes are
encrypted images in @people, and that the login screen starts the desktop in
one. The session is shared by the checks; each asks it for one thing."""

import base64
import json
import os
import re
import shlex
import time

import pytest
from conftest import wait_until

USER = "shapebit-test"
AUTOLOGIN = "/etc/sddm.conf.d/zz-desktop-check.conf"
AUTOSTART = "/etc/xdg/autostart/zz-desktop-check.desktop"
AUTOSTARTED = "/tmp/desktop-autostart-check"
DESKTOP = "/org/freedesktop/portal/desktop"


@pytest.fixture(scope="module")
def home(host):
    """The home, active, and removed afterwards. Small: the test is about where
    homes live, not how big they get."""
    password = base64.b64encode(os.urandom(24)).decode()
    created = host.run(f"NEWPASSWORD={shlex.quote(password)} homectl create {USER} --disk-size=512M")
    assert created.rc == 0, created.stderr
    activated = host.run(f"PASSWORD={shlex.quote(password)} homectl activate {USER}")
    assert activated.rc == 0, activated.stderr
    yield USER
    host.run(f"rm -f {AUTOLOGIN} {AUTOSTART} {AUTOSTARTED}")
    host.run(f"loginctl terminate-user {USER}")
    # homed is busy with the home while the session ends; it may also deactivate
    # the home itself then.
    for _ in range(30):
        state = re.search(r"State: (\S+)", host.run(f"homectl inspect {USER}").stdout)
        if state and state.group(1) == "inactive":
            break
        if state and state.group(1) == "active" and host.run(f"homectl deactivate {USER}").rc == 0:
            break
        time.sleep(1)
    # Restarting the login screen again may exceed its start limit.
    host.run("systemctl reset-failed sddm.service")
    host.run("systemctl restart sddm.service")
    removed = host.run(f"homectl remove {USER}")
    assert removed.rc == 0, removed.stderr


@pytest.fixture(scope="module")
def session(host, home):
    """The desktop, which the login screen starts: signed in automatically, since
    the home is already unlocked, with an application that starts with every
    session. Yields the user's D-Bus and hyprctl commands."""
    host.run(f"mkdir -p {os.path.dirname(AUTOLOGIN)}; rm -f {AUTOSTARTED}")
    host.run(f"printf '[Autologin]\\nUser=%s\\nSession=desktop.desktop\\n' {USER} >{AUTOLOGIN}")
    host.run(
        f"printf '[Desktop Entry]\\nType=Application\\nName=Check\\nExec=touch %s\\n' {AUTOSTARTED} >{AUTOSTART}"
    )
    assert host.run("systemctl restart sddm.service").rc == 0
    started = wait_until(
        lambda: host.run(f"pgrep -u {USER} -x Hyprland").rc == 0 and host.run(f"pgrep -u {USER} -x qs").rc == 0,
        timeout=60,
    )
    assert started, "the login screen did not start the desktop"
    return Session(host)


class Session:
    def __init__(self, host):
        self.host = host
        self.uid = host.user(USER).uid

    def bus(self, arguments):
        return self.host.run(f"busctl --user -M {USER}@ {arguments}")

    def answers(self, name, path):
        return self.bus(f"call {name} {path} org.freedesktop.DBus.Peer Ping").rc == 0

    def portal_offers(self, interface):
        return self.bus(f"get-property org.freedesktop.portal.Desktop {DESKTOP} org.freedesktop.portal.{interface} version").rc == 0

    def unit_active(self, unit):
        return self.host.run(f"systemctl --user -M {USER}@ is-active {unit}").stdout.strip() == "active"

    def hyprctl(self, arguments):
        return self.host.run(
            f"setpriv --reuid={USER} --regid={USER} --init-groups env XDG_RUNTIME_DIR=/run/user/{self.uid} "
            f"hyprctl --instance 0 {arguments}"
        )


def test_home_is_a_luks2_image_in_home(sh, home):
    bindings = list(json.loads(sh(f"homectl inspect -j {home}"))["binding"].values())
    assert len(bindings) == 1
    assert bindings[0]["storage"] == "luks" and bindings[0]["imagePath"] == f"/home/{home}.home"


def test_home_image_is_in_people(sh, home):
    assert sh(f"findmnt -no FSROOT -T /var/home/{home}.home").strip() == "/@people"


def test_home_user_resolves_through_nss(sh, home):
    sh(f"getent passwd {home}")


def test_active_home_is_btrfs_on_dm_crypt(sh, home):
    assert re.match(r"btrfs /dev/mapper/home-", sh(f"findmnt -no FSTYPE,SOURCE /home/{home}"))


def test_login_screen_starts_the_desktop_in_a_home(session):
    assert session.host.run(f"pgrep -u {USER} -x Hyprland").rc == 0


def test_desktop_locks_the_screen_before_sleep(session):
    # The desktop's hypridle delays sleep until the screen is locked.
    def inhibits():
        listing = session.host.run("systemd-inhibit --list --no-legend").stdout
        return re.search(rf"^hypridle .* {USER} .* sleep .* delay", listing, re.M)

    assert wait_until(inhibits, timeout=10)


def test_session_reaches_graphical_session_target(session):
    assert wait_until(lambda: session.unit_active("graphical-session.target"), timeout=20)


def test_session_starts_xdg_autostart_applications(session):
    def owner():
        return session.host.run(f"stat -c %U {AUTOSTARTED}").stdout.strip()

    assert wait_until(lambda: owner() == USER, timeout=20)


def test_session_offers_the_secret_service(session):
    assert session.answers("org.freedesktop.secrets", "/org/freedesktop/secrets")


def test_session_shares_the_screen_through_the_portal(session):
    assert session.portal_offers("ScreenCast")


def test_session_applications_show_no_window_buttons(session):
    # Applications in Flatpak read the window buttons through the portal.
    reply = session.bus(
        f"call org.freedesktop.portal.Desktop {DESKTOP} org.freedesktop.portal.Settings "
        "ReadOne ss org.gnome.desktop.wm.preferences button-layout"
    )
    assert reply.stdout.strip() == 'v s ":"'


@pytest.mark.parametrize(
    "interface",
    ["FileChooser", "Screenshot", "OpenURI", "Account", "Background",
     "DynamicLauncher", "Inhibit", "Notification", "Wallpaper", "Secret"],
)  # fmt: skip
def test_session_offers_the_portals(session, interface):
    assert session.portal_offers(interface)


def test_shells_portal_answers_and_listens(session):
    # D-Bus starts the shell's backend in the session, and the shell listens
    # for its questions.
    assert session.answers("org.freedesktop.impl.portal.desktop.shell", DESKTOP)
    listing = session.host.run(f"ls /run/user/{session.uid}/desktop/")
    assert re.search(r"portal-wayland-.*\.sock", listing.stdout)


def test_session_asks_for_an_administrators_password(session):
    # An action that needs an administrator makes the shell ask for the password
    # (its "authorization" surface); the question is left unanswered.
    session.hyprctl("""dispatch 'hl.dsp.exec_cmd("pkexec true")'""")
    try:
        assert wait_until(lambda: "namespace: authorization" in session.hyprctl("layers").stdout, timeout=15)
    finally:
        session.host.run(f"pkill -u {USER} -x pkexec")


def test_session_shows_notifications(session):
    reply = session.bus(
        "call org.freedesktop.Notifications /org/freedesktop/Notifications "
        "org.freedesktop.Notifications GetServerInformation"
    )
    assert '"quickshell"' in reply.stdout


def test_session_keeps_copied_text(session):
    assert session.host.run(f"pgrep -u {USER} -f 'clipman store'").rc == 0


@pytest.mark.parametrize(
    "unit", ["pipewire.service", "wireplumber.service", "pipewire-pulse.socket", "app-update.timer"]
)
def test_session_unit_is_active(session, unit):
    assert wait_until(lambda: session.unit_active(unit))


def test_session_runs_the_connection_agent(session):
    # It joins networks and pairs devices for the shell.
    assert session.host.run(f"pgrep -u {USER} -f /usr/libexec/desktop/connection-agent").rc == 0


def test_session_lists_flatpak_applications(session):
    # Flatpak's applications are in the shell's Apps: its exports are on the
    # session's data path.
    shell = session.host.run(f"pgrep -u {USER} -x qs").stdout.split()[0]
    environment = session.host.file(f"/proc/{shell}/environ").content.decode().split("\0")
    assert [line for line in environment if line.startswith("XDG_DATA_DIRS=") and "/var/lib/flatpak/exports/share" in line]


def test_logging_out_ends_the_session(session):
    # Log out as the account panel does: Hyprland's exit.
    session.hyprctl("dispatch 'hl.dsp.exit()'")

    def ended():
        listing = session.host.run("loginctl list-sessions --no-legend").stdout.splitlines()
        return not [line for line in listing if line.split()[2] == USER and line.split()[5] != "manager"]

    assert wait_until(ended)
