#!/usr/bin/env bash
# Checks run inside the container image (`make check`); uses only tools the image ships.
set -uo pipefail

failed=0
check() {
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; failed=1; fi
}

. /etc/os-release
check "os-release identifies ShapeBit OS" test "$ID" = shapebit
# A rolling release: each build is identified only by its image version,
# the build date and commit (20261030_e0920a), or dev for local builds.
check "os-release carries the image version" test -n "${IMAGE_VERSION:-}"
image_version_format() { [[ $IMAGE_VERSION == dev || $IMAGE_VERSION =~ ^[0-9]{8}_[0-9a-f]{6}$ ]]; }
check "image version is the build date and commit" image_version_format
check "os-release names no release line" test -z "${VERSION_ID:-}${VERSION:-}"
no_weak_deps() { [[ $(dnf --dump-main-config 2>/dev/null | awk '$1 == "install_weak_deps" { print $3 }') == 0 ]]; }
check "dnf installs no weak dependencies" no_weak_deps
check "default target is graphical" test "$(systemctl get-default)" = graphical.target
check "login screen is enabled" systemctl -q is-enabled sddm.service
login_setting() { grep -qx "$1" /usr/lib/sddm/sddm.conf.d/10-login.conf; }
check "login screen uses the login theme" login_setting Current=login
check "login theme is present" test -s /usr/share/sddm/themes/login/Main.qml
check "login screen lists systemd-homed users" login_setting MaximumUid=60513
has_login_font() { fc-list : family | grep -qx 'Instrument Sans'; }
check "login theme's font is installed" has_login_font
check "desktop session is installed" grep -qx 'TryExec=uwsm' /usr/share/wayland-sessions/desktop.desktop
only_desktop_session() { [[ $(ls /usr/share/wayland-sessions) == desktop.desktop ]] && ! compgen -G '/usr/share/xsessions/*' >/dev/null; }
check "login screen offers only the desktop session" only_desktop_session
has_command() { command -v "$1" >/dev/null; }
check "desktop session's compositor is installed" has_command start-hyprland
check "desktop shell is installed" test -s /usr/share/desktop/shell/shell.qml
check "desktop shell's runtime is installed" has_command qs
# Hyprland refuses to run as root and needs a runtime directory even to
# verify its configuration.
verify_compositor_config() {
  setpriv --reuid=nobody --regid=nobody --clear-groups sh -c \
    'XDG_RUNTIME_DIR=$(mktemp -d) exec Hyprland --verify-config --config /usr/share/desktop/compositor/hyprland.lua' >/dev/null
}
check "desktop compositor configuration is valid" verify_compositor_config
has_desktop_tools() { for tool in grim slurp wf-recorder xdg-user-dir wl-copy; do has_command "$tool" || return 1; done; }
check "desktop's capture tools are installed" has_desktop_tools
check "desktop's clipboard reader is installed" has_command wl-paste
check "desktop's sound server is installed" has_command pipewire
check "desktop's sound session manager is installed" has_command wireplumber
check "applications' PulseAudio sound reaches PipeWire" has_command pipewire-pulse
check "desktop's battery service is installed" has_command upower
gi_imports() { python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio, GLib' 2>/dev/null; }
check "desktop's Python scripts find GObject" gi_imports
check "desktop's idle handler is installed" has_command hypridle
check "desktop's portal is Hyprland's" grep -qx 'default=hyprland' /usr/share/xdg-desktop-portal/shapebit-portals.conf
check "Hyprland's portal is installed" test -s /usr/share/xdg-desktop-portal/portals/hyprland.portal
check "desktop's secrets portal is gnome-keyring's" grep -qx 'org.freedesktop.impl.portal.Secret=gnome-keyring' /usr/share/xdg-desktop-portal/shapebit-portals.conf
check "gnome-keyring's portal is installed" test -s /usr/share/xdg-desktop-portal/portals/gnome-keyring.portal
# Everything else is the shell's, which its portal offers.
shell_portals() {
  local interface
  for interface in FileChooser Screenshot AppChooser Access Account Background DynamicLauncher Inhibit Notification Settings Wallpaper; do
    grep -qx "org.freedesktop.impl.portal.$interface=shell" /usr/share/xdg-desktop-portal/shapebit-portals.conf &&
      grep -q "org.freedesktop.impl.portal.$interface\b" /usr/share/xdg-desktop-portal/portals/shell.portal || return 1
  done
}
check "desktop's other portals are the shell's" shell_portals
is_python() { test -x "$1" && python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$1"; }
shell_portal_starts() {
  grep -qx 'Exec=/usr/libexec/desktop/portal' /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.shell.service &&
    is_python /usr/libexec/desktop/portal
}
check "D-Bus starts the shell's portal" shell_portal_starts
# Hyprland's portal reads its configuration from XDG_CONFIG_HOME/hypr only.
shell_share_picker() {
  is_python /usr/libexec/desktop/share-picker &&
    grep -q 'custom_picker_binary = /usr/libexec/desktop/share-picker' /usr/share/desktop/portal/hypr/xdph.conf &&
    systemctl --user --global cat xdg-desktop-portal-hyprland.service 2>/dev/null |
    grep -qx 'Environment=XDG_CONFIG_HOME=/usr/share/desktop/portal'
}
check "sharing the screen asks through the shell" shell_share_picker
check "desktop's connection agent is installed" is_python /usr/libexec/desktop/connection-agent
check "Flatpak is installed" has_command flatpak
check "Distrobox is installed" has_command distrobox
distrobox_image() { grep -qx "container_image_default=\"registry.fedoraproject.org/fedora-toolbox:$(rpm -E %fedora)\"" /usr/share/distrobox/distrobox.conf; }
check "Distrobox starts from this Fedora's toolbox image" distrobox_image
# Flatpak adds the remotes in /usr/share/flatpak/remotes.d by itself.
flathub_remote() { flatpak remotes --system --columns=name,url | grep -q '^flathub[[:space:]]*https://dl.flathub.org/repo/'; }
check "Flathub is a system remote" flathub_remote
check "Files is installed" test -s /usr/share/applications/org.gnome.Nautilus.desktop
check "Image Viewer opens TIFF images" grep -qx 'image/tiff=org.gnome.Loupe.desktop' /usr/share/applications/shapebit-mimeapps.list
check "app installer is installed" is_python /usr/libexec/desktop/app-install
check "app catalog is installed" is_python /usr/libexec/desktop/app-catalog
check "app remover is installed" is_python /usr/libexec/desktop/app-remove
check "apps update daily" test -L /usr/lib/systemd/user/timers.target.wants/app-update.timer
check "system updates are checked on a timer" systemctl -q is-enabled os-update.timer
check "system update check is installed" test -x /usr/libexec/os-update
check "the person at the computer may check for updates" test -s /usr/share/polkit-1/rules.d/50-os-update.rules
check "Files draws image previews" test -s /usr/share/thumbnailers/glycin-image-rs.thumbnailer
check "Files draws video previews" test -s /usr/share/thumbnailers/gst-video-thumbnailer.thumbnailer
check "applications outside Flatpak use the portals" grep -qx 'GTK_USE_PORTAL=1' /usr/lib/environment.d/60-portals.conf
no_window_buttons() { [[ $(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.wm.preferences button-layout) == "':'" ]]; }
check "applications show no window buttons" no_window_buttons
check "desktop's brightness control is installed" has_command brightnessctl
check "desktop's clipboard keeper is installed" has_command clipman
check "power profiles are enabled" systemctl -q is-enabled power-profiles-daemon.service
check "secret service is installed" has_command gnome-keyring-daemon
check "login unlocks the secret service" test -e /usr/lib64/security/pam_gnome_keyring.so
has_mono_font() { fc-list : family | grep -qx 'JetBrains Mono'; }
check "desktop's monospace font is installed" has_mono_font
no_copr_repo() { ! grep -rqs copr /etc/yum.repos.d; }
check "no third-party repository is left configured" no_copr_repo
check "sshd is enabled" systemctl -q is-enabled sshd.service
check "NetworkManager is enabled" systemctl -q is-enabled NetworkManager.service
check "systemd-homed is enabled" systemctl -q is-enabled systemd-homed.service
no_first_boot_prompt() { ! systemctl -q is-enabled systemd-homed-firstboot.service; }
check "no first-boot prompt: the installer creates the first owner" no_first_boot_prompt
check "PAM uses systemd-homed" grep -q pam_systemd_home /etc/pam.d/system-auth
initramfs_skips_var() { lsinitrd /usr/lib/modules/*/initramfs.img -f usr/lib/composefs/setup-root-conf.toml | grep -q '^mount = "none"'; }
check "initramfs leaves /var to fstab" initramfs_skips_var
check "signed systemd-boot is present" test -s /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
has_uki() { compgen -G '/boot/EFI/Linux/*.efi' >/dev/null; }
check "UKI is present" has_uki
uki_has_pcr_policy() { grep -aq '\.pcrsig' /boot/EFI/Linux/*.efi && grep -aq '\.pcrpkey' /boot/EFI/Linux/*.efi; }
check "UKI carries a signed PCR policy" uki_has_pcr_policy
has_sb_keys() { for key in PK KEK db; do test -s "/usr/lib/bootc/install/secureboot-keys/auto/$key.auth" || return 1; done; }
check "Secure Boot keys are present" has_sb_keys

exit "$failed"
