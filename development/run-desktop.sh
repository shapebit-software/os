#!/usr/bin/env bash
# Runs the desktop in a window for development (make run), with a session bus
# of its own, so that what runs inside reaches the desktop's own services
# rather than the host's: the shell's notification server, and the portals as
# the image sets them up (packages/portal/), from this tree: xdg-desktop-portal with
# portals.conf, the shell's backend, and Hyprland's portal with the shell's
# share picker. Hyprland gives the bus its display (packages/windows/hyprland.lua).
# Nothing here is installed.
# Usage: run-desktop.sh (called by `make run`, in the development image, with
# the environment the Makefile sets).
set -euo pipefail

packages=$(cd "$(dirname "$0")/../packages" && pwd)

dir=$(mktemp -d "${XDG_RUNTIME_DIR:?}/desktop-dev.XXXXXX")
trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/services" "$dir/portals" "$dir/hypr"

# The portals and their configuration: the frontend reads both from here,
# for the desktop name ShapeBit.
cp "$packages/portal/shell.portal" "$dir/portals/"
for portal in hyprland oo7-portal; do
  [ ! -e "/usr/share/xdg-desktop-portal/portals/$portal.portal" ] ||
    cp "/usr/share/xdg-desktop-portal/portals/$portal.portal" "$dir/portals/"
done
cp "$packages/portal/portals.conf" "$dir/portals/shapebit-portals.conf"
sed "s|/usr/libexec/desktop/share-picker|$packages/screen-sharing/share-picker|" "$packages/screen-sharing/xdph.conf" >"$dir/hypr/xdph.conf"
# The person's Flatpak apps too, which the host's session may not know of if it
# started before Flatpak was installed; and the system's colors, installed
# from the image's source by make run (DEV_SYSTEM), for the portal.
data_dirs="${DEV_SYSTEM:?}/usr/share:${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
# The external packages that make run installed there, if `make rpm` built
# them: the assistant's model server, and dictation's speech engine.
llama=$DEV_SYSTEM/usr/libexec/llama/llama-server
[ ! -x "$llama" ] || export ASSISTANT_LLAMA=$llama
for site in "$DEV_SYSTEM"/usr/lib64/python3*/site-packages; do
  [ ! -d "$site" ] || export PYTHONPATH=$site
done

# D-Bus starts them on the first request, from here before the system's.
cat >"$dir/services/org.freedesktop.portal.Desktop.service" <<EOF
[D-BUS Service]
Name=org.freedesktop.portal.Desktop
Exec=/usr/bin/env XDG_CURRENT_DESKTOP=ShapeBit XDG_DESKTOP_PORTAL_DIR=$dir/portals XDG_DATA_DIRS=$data_dirs /usr/libexec/xdg-desktop-portal
EOF
cat >"$dir/services/org.freedesktop.impl.portal.desktop.shell.service" <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.shell
Exec=$packages/portal/portal
EOF
cat >"$dir/services/org.freedesktop.impl.portal.desktop.hyprland.service" <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.hyprland
Exec=/usr/bin/env XDG_CONFIG_HOME=$dir /usr/libexec/xdg-desktop-portal-hyprland
EOF
cat >"$dir/bus.conf" <<EOF
<busconfig>
  <servicedir>$dir/services</servicedir>
  <include>/usr/share/dbus-1/session.conf</include>
</busconfig>
EOF

# The session bus here has no keyring; the assistant keeps keys and sign-ins
# in the host's, which is unlocked (assistant/providers.py).
[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || export ASSISTANT_KEYRING_BUS="$DBUS_SESSION_BUS_ADDRESS"
dbus-run-session --config-file="$dir/bus.conf" -- \
  env XDG_DATA_DIRS="$data_dirs" start-hyprland -- --config "$packages/windows/hyprland.lua"
