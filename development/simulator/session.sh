#!/usr/bin/env bash
# The simulator's session (README.md), as the developer, in its container,
# where simulate.py has installed the tree: a session bus, a system bus with
# the scenario's fake services (fakes.py), the compositor in a window on the
# host's display, and the session's units, as UWSM starts them with
# graphical-session.target: each one's ExecStartPre and ExecStart. Ends with
# the compositor, when its window closes.
# Usage: session.sh SCENARIO.toml (run by simulate.py).
set -euo pipefail
here=$(dirname "$(realpath "$0")")

DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --session --fork --print-address)
DBUS_SYSTEM_BUS_ADDRESS=$(dbus-daemon --config-file="$here/system-bus.conf" --fork --print-address)
export DBUS_SESSION_BUS_ADDRESS DBUS_SYSTEM_BUS_ADDRESS
python3 "$here/fakes.py" "$1"

# The compositor, as the session starts it (packages/windows/system/desktop.desktop);
# its sockets are the only ones in this runtime folder.
start-hyprland -- --config /usr/share/desktop/compositor/hyprland.lua &
compositor=$!
until [ -S "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock ] && [ -S "$XDG_RUNTIME_DIR"/wayland-? ]; do
  kill -0 $compositor 2>/dev/null || { echo "error: the compositor did not start" >&2; exit 1; }
  sleep 0.2
done 2>/dev/null
HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock)")
WAYLAND_DISPLAY=$(basename "$XDG_RUNTIME_DIR"/wayland-?)
export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY

# Its display is its window, which has no size in millimetres, so "auto"
# doubles its scale: the window's own pixels instead, whatever size it takes.
# Settings > Display still changes it, as on a computer.
hyprctl dispatch 'function() hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 }) end' >/dev/null

# A unit's commands of KEY, as a shell runs them: systemd's prefixes off, its
# $$ as $, and %h as the home folder.
commands() {
  sed -n "s/^$1=[-@:+!]*//p" "$2" | sed -e 's/\$\$/$/g' -e "s|%h|$HOME|g"
}
for unit in /usr/lib/systemd/user/graphical-session.target.wants/*.service; do
  [ -e "$unit" ] || continue
  while IFS= read -r line; do bash -c "$line"; done < <(commands ExecStartPre "$unit")
  while IFS= read -r line; do bash -c "$line" & done < <(commands ExecStart "$unit")
done

wait $compositor
