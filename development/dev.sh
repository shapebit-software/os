#!/usr/bin/env bash
# Runs a command in the development image (development/Containerfile), as the
# developer, in this repository, with their home folder, the host's network,
# KVM for the VMs, and the settings make exports (DEV_ENV, their names). With
# --desktop, also with what a window needs from the host's session: its
# Wayland display, its runtime folder (PipeWire, the session bus, the user
# manager), the system bus, and the GPU. With DEV_NETWORK=private, the command
# gets a network of its own instead of the host's, for servers that listen on
# every address, such as openQA's VNC.
# Usage: dev.sh [--desktop] COMMAND... (called by make, with DEV_ENGINE, DEV_IMAGE, and DEV_ENV).
set -euo pipefail
: "${DEV_ENGINE:?}" "${DEV_IMAGE:?}" "${DEV_ENV:?}"

args=(--rm --init --security-opt label=disable
  -v "$HOME:$HOME" -v "$PWD:$PWD" -w "$PWD" -e HOME -e USER -e MAKEFLAGS -e TERM)
for name in $DEV_ENV; do args+=(-e "$name"); done
[ "${DEV_NETWORK:-host}" = private ] || args+=(--network host)
[ ! -t 0 ] || args+=(-it)

# The developer's own user ID, so that what the command writes is theirs.
# Podman maps it, and adds the account; Docker takes the host's accounts.
case $DEV_ENGINE in
  *podman*) args+=(--userns=keep-id --group-add keep-groups) ;;
  *) args+=(--user "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro)
     for group in $(id -G); do args+=(--group-add "$group"); done ;;
esac

# A device, with its group: the developer may reach it only through the
# session's ACLs, which the container doesn't carry.
device() {
  [ -e "$1" ] || return 0
  args+=(--device "$1")
  for group in $(find "$1" -maxdepth 1 \( -type c -o -type b \) -exec stat -c %g {} + | sort -u); do
    args+=(--group-add "$group")
  done
}
device /dev/kvm

if [ "$1" = --desktop ]; then
  shift
  : "${XDG_RUNTIME_DIR:?}" "${WAYLAND_DISPLAY:?}"
  args+=(-v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR" -e XDG_RUNTIME_DIR -e WAYLAND_DISPLAY
    -e DBUS_SESSION_BUS_ADDRESS -e LANG -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)
  device /dev/dri
fi

# DEV_ENGINE is unquoted on purpose: it may be a command with arguments.
exec $DEV_ENGINE run "${args[@]}" "$DEV_IMAGE" "$@"
