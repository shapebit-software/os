#!/usr/bin/env bash
# Runs a command in the development image (images/development/Containerfile), as the
# developer, in this repository, with their home folder, the host's network,
# KVM for the VMs, and the settings make exports (DEV_ENV, their names). With
# --desktop, also with what a window needs from the host's session: its
# Wayland display, its runtime folder (PipeWire, the session bus, the user
# manager), the system bus, and the GPU. With DEV_NETWORK=private, the command
# gets a network of its own instead of the host's, for servers that listen on
# every address, such as openQA's VNC.
# Usage: dev.sh [--desktop] COMMAND... (called by make, with ENGINE, DEV_IMAGE, and DEV_ENV).
set -euo pipefail
: "${ENGINE:?}" "${DEV_IMAGE:?}" "${DEV_ENV:?}"

# The variables NAME... that are set, with their values: an engine run through
# sudo doesn't see the developer's environment.
pass() {
  local name
  for name; do [[ ! -v $name ]] || args+=(-e "$name=${!name}"); done
}

args=(--rm --init --security-opt label=disable -v "$HOME:$HOME" -v "$PWD:$PWD" -w "$PWD")
pass HOME USER MAKEFLAGS TERM $DEV_ENV
[ "${DEV_NETWORK:-host}" = private ] || args+=(--network host)
[ ! -t 0 ] || args+=(-it)

# The developer's own user ID and groups, so that what the command writes is
# theirs, with the host's accounts. ENGINE is root-capable (Makefile), so it
# runs the container as root unless told otherwise.
args+=(--user "$(id -u):$(id -g)" -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro)
for group in $(id -G); do args+=(--group-add "$group"); done

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
  args+=(-v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR" -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)
  pass XDG_RUNTIME_DIR WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS LANG
  device /dev/dri
fi

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
exec $ENGINE run "${args[@]}" "$DEV_IMAGE" "$@"
