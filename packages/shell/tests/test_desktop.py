"""The container image: the desktop session, its portals, and its applications."""

import ast
import json

import pytest

pytestmark = pytest.mark.system_image


PORTALS = "/usr/share/xdg-desktop-portal/shapebit-portals.conf"
PORTAL_DIR = "/usr/share/xdg-desktop-portal/portals"


@pytest.mark.parametrize(
    "command",
    [
        "start-hyprland", "hyprland-dialog", "qs", "grim", "slurp", "wf-recorder", "xdg-user-dir", "wl-copy", "wl-paste",
        "pipewire", "wireplumber", "pipewire-pulse", "upower", "hypridle", "brightnessctl", "clipman",
        "secret-tool", "flatpak", "distrobox", "pw-record", "pw-play", "wtype", "setpriv", "ffmpeg", "ffprobe",
    ],
)  # fmt: skip
def test_desktop_command_is_installed(host, command):
    assert host.exists(command)


@pytest.mark.parametrize(
    "path",
    [
        "/usr/libexec/desktop/portal",
        "/usr/libexec/desktop/share-picker",
        "/usr/libexec/desktop/microphone-level",
        "/usr/libexec/desktop/app-install",
        "/usr/libexec/desktop/app-catalog",
        "/usr/libexec/desktop/app-remove",
        "/usr/libexec/desktop/downloads",
        "/usr/libexec/desktop/camera",
        "/usr/libexec/desktop/skip-silence",
    ],
)
def test_desktop_helper_is_python(host, path):
    helper = host.file(path)
    assert helper.mode & 0o111
    ast.parse(helper.content_string)


# The helpers in Rust (packages/network/Cargo.toml).
@pytest.mark.parametrize("path", ["/usr/libexec/desktop/connection-agent"])
def test_desktop_helper_is_a_program(host, path):
    helper = host.file(path)
    assert helper.mode & 0o111
    assert helper.content[:4] == b"\x7fELF"


@pytest.mark.parametrize(
    "path",
    [
        "/usr/share/desktop/shell/shell.qml",
        f"{PORTAL_DIR}/hyprland.portal",
        f"{PORTAL_DIR}/oo7-portal.portal",
        "/usr/libexec/oo7-daemon",
        "/usr/share/applications/org.gnome.Nautilus.desktop",
        "/usr/share/applications/org.gnome.Ptyxis.desktop",
        "/usr/share/polkit-1/rules.d/50-os-update.rules",
        "/usr/share/thumbnailers/glycin-image-rs.thumbnailer",
        "/usr/share/thumbnailers/gst-video-thumbnailer.thumbnailer",
    ],
)
def test_desktop_file_is_installed(host, path):
    assert host.file(path).size > 0


def test_apps_shows_no_session_tools(host):
    # UWSM's unit manager is for the session, not for people; the command stays.
    assert not host.file("/usr/share/applications/uuctl.desktop").exists
    assert host.file("/usr/bin/uuctl").exists


@pytest.mark.parametrize("helper", ["dictate", "hear"])
def test_dictation_helpers_are_installed(host, sh, helper):
    assert host.file(f"/usr/libexec/desktop/{helper}").mode & 0o111
    sh(f"python3 -c 'import ast; ast.parse(open(\"/usr/libexec/desktop/{helper}\").read())'")


def test_the_assistant_has_its_sound_when_it_hears_a_request(host):
    # assistant/src/shell/Assistant.qml plays it with pw-play.
    assert host.file("/usr/share/sounds/freedesktop/stereo/message.oga").size > 0
    assert host.exists("pw-play")


def test_dictation_has_its_runtime_but_no_speech_model(sh, host):
    # The engine gets as far as loading Parakeet only with sherpa-onnx and NumPy
    # in place. Speech models are extras, downloaded when the person chooses.
    sh("python3 -c 'import numpy, sherpa_onnx, onnxruntime'")
    assert host.file("/usr/libexec/desktop/dictate-engine").mode & 0o111
    for path in ("/usr/share/parakeet", "/usr/share/whisper", "/usr/bin/whisper-cli", "/usr/lib64/dictation"):
        assert not host.file(path).exists


def test_sherpa_is_shapebits_build_on_fedoras_onnx_runtime(sh, host):
    # packages/dictation/external/sherpa-onnx: one ONNX Runtime in the image, Fedora's, and the bundled
    # libraries' licenses with the package.
    assert sh("rpm -q --qf '%{NAME}' python3-sherpa-onnx") == "python3-sherpa-onnx"
    module = sh("python3 -c 'import sherpa_onnx.lib._sherpa_onnx as m; print(m.__file__)'").strip()
    libraries = sh("ldd %s", module)
    assert "not found" not in libraries
    path = next(line.split()[2] for line in libraries.splitlines() if "libonnxruntime.so" in line)
    assert sh("rpm -qf --qf '%%{NAME}' %s", path) == "onnxruntime"
    package = sh("rpm -ql python3-sherpa-onnx").split()
    assert not [f for f in package if "/libonnxruntime" in f]
    for library in ("kaldi-native-fbank", "kissfft", "utf8proc", "openfst", "hclust-cpp", "eigen"):
        assert host.file(f"/usr/share/licenses/python3-sherpa-onnx/{library}").is_directory, library
    # And it declares them, for the SBOM.
    assert "bundled(kissfft)" in sh("rpm -q --provides python3-sherpa-onnx")


def test_extras_can_be_downloaded_by_administrators(host, sh):
    assert host.file("/usr/libexec/desktop/extra").mode & 0o111
    assert "d /var/lib/extras 2775 root wheel" in host.file("/usr/lib/tmpfiles.d/extras.conf").content_string
    catalog = json.loads(sh("EXTRAS_DIR=/tmp /usr/libexec/desktop/extra list"))
    assert "parakeet" in [extra["id"] for extra in catalog["extras"]]


def test_assistant_is_installed_and_starts_with_its_socket(host, sh):
    sh("python3 -c 'import sys; sys.path.insert(0, \"/usr/libexec/desktop/assistant\"); import providers; assert not providers.PROVIDERS'")
    for name in ("assistant", "actions.py", "models.py", "skills.py", "web.py", "providers.py", "chatgpt.py"):
        sh(f"python3 -c 'import ast; ast.parse(open(\"/usr/libexec/desktop/assistant/{name}\").read())'")
    assert host.file("/usr/libexec/desktop/assistant/assistant").mode & 0o111
    assert host.file("/usr/share/desktop/assistant/skills/writing.md").content_string.startswith("---\nname: writing\n")
    units = "/usr/lib/systemd/user"
    for unit in ("assistant.socket", "assistant.service", "language-model@.socket", "language-model@.service",
                 "language-model-ready@.service", "llama-server@.service"):
        assert host.file(f"{units}/{unit}").size > 0
    assert host.file(f"{units}/sockets.target.wants/assistant.socket").linked_to == f"{units}/assistant.socket"


def test_speech_model_starts_with_its_socket(host):
    units = "/usr/lib/systemd/user"
    for unit in ("speech-model.socket", "speech-model.service"):
        assert host.file(f"{units}/{unit}").size > 0
    assert host.file(f"{units}/sockets.target.wants/speech-model.socket").linked_to == f"{units}/speech-model.socket"
    assert "dictate-engine --serve" in host.file(f"{units}/speech-model.service").content_string


def test_assistant_model_is_an_extra_not_in_the_image(host, sh):
    models = json.loads(host.file("/usr/share/desktop/assistant/models.json").content_string)
    local = [m["extra"] for m in models if m["where"] == "local"]
    catalog = json.loads(sh("EXTRAS_DIR=/tmp /usr/libexec/desktop/extra list"))
    assert "gemma-4-e2b" in local and set(local) <= {extra["id"] for extra in catalog["extras"]}
    assert not host.file("/var/lib/extras/gemma-4-e2b").exists


def test_llama_server_is_shapebits_package_with_its_own_libraries(sh, host):
    # packages/assistant/external/llama-server: every file is the package's, its libraries stay
    # private, and its notices come with it.
    assert "version: " in sh("/usr/libexec/llama/llama-server --version 2>&1")
    assert "not found" not in sh("ldd /usr/libexec/llama/llama-server")
    assert host.file("/usr/libexec/llama/libggml-cpu-haswell.so").size > 0
    assert sh("rpm -qf --qf '%{NAME}\\n' /usr/libexec/llama/llama-server /usr/libexec/llama/libggml-cpu-haswell.so").split() == [
        "llama-server", "llama-server"]
    assert "libggml" not in sh("rpm -q --provides llama-server")
    for notice in ("LICENSE", "LICENSE-jsonhpp", "LICENSE-cpp-httplib", "LICENSE-xxhash"):
        assert host.file(f"/usr/share/licenses/llama-server/{notice}").size > 0
    assert "Copyright 2024 Mozilla Foundation" in host.file("/usr/share/licenses/llama-server/LICENSE-llamafile").content_string


def test_compositor_configuration_is_valid(sh):
    # Hyprland refuses to run as root and needs a runtime directory even to
    # verify its configuration.
    sh(
        "setpriv --reuid=nobody --regid=nobody --clear-groups sh -c "
        "'XDG_RUNTIME_DIR=$(mktemp -d) exec Hyprland --verify-config "
        "--config /usr/share/desktop/compositor/hyprland.lua'"
    )


def test_compositor_shows_no_donation_or_news_windows(host):
    compositor = host.file("/usr/share/desktop/compositor/hyprland.lua").content_string
    assert "ecosystem = { no_update_news = true, no_donation_nag = true }" in compositor


def test_compositor_does_not_move_the_pointer_to_focused_windows(host):
    compositor = host.file("/usr/share/desktop/compositor/hyprland.lua").content_string
    assert "cursor = { no_warps = true }" in compositor


def test_python_scripts_find_gobject(sh):
    sh("""python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio, GLib'""")


def test_portals_are_hyprlands_and_oo7s(host):
    lines = host.file(PORTALS).content_string.splitlines()
    assert "default=hyprland" in lines
    assert "org.freedesktop.impl.portal.Secret=oo7-portal" in lines


def test_only_oo7_offers_the_secret_service(host):
    # Two providers would race for org.freedesktop.secrets.
    assert not host.package("gnome-keyring").is_installed


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


def test_unfinished_downloads_go_on_at_sign_in(host):
    assert host.file("/usr/lib/systemd/user/graphical-session.target.wants/downloads.service").is_symlink


def test_system_update_check_is_installed(host):
    assert host.file("/usr/libexec/os-update").mode & 0o111


def test_applications_outside_flatpak_use_the_portals(host):
    assert "GTK_USE_PORTAL=1" in host.file("/usr/lib/environment.d/60-portals.conf").content_string.splitlines()


def test_applications_show_no_window_buttons(sh):
    layout = sh("GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.wm.preferences button-layout")
    assert layout.strip() == "':'"


def test_monospace_font_is_installed(sh):
    assert "JetBrains Mono" in sh("fc-list : family").splitlines()


def test_the_desktops_files_are_their_features_packages(sh):
    # packages/: what each feature's Makefile installs, built with the image.
    paths = {"/usr/libexec/desktop/extra": "shapebit-extras", "/usr/share/desktop/shell/shell.qml": "shapebit-shell",
             "/usr/share/licenses/parakeet/NOTICE": "shapebit-extras",
             "/usr/share/desktop/compositor/hyprland.lua": "shapebit-windows"}
    assert sh("rpm -qf --qf '%{NAME}\\n' " + " ".join(paths)).split() == list(paths.values())
