#!/usr/bin/env bash
# Runs a command in the development image (image/Containerfile, its development stage), as the
# developer, in this repository, with their home folder, the host's network,
# KVM for the VMs, the settings make exports (DEV_ENV, their names), and the
# host's container engine (ENGINE), whose client in the image reaches it
# through its socket. The repository and the home folder have the same paths in
# the image as on the host, so the paths a command gives the engine are the
# host's. With --desktop, also with what a VM's window needs from the host's
# session: its Wayland display and PipeWire, in its runtime folder, the GPU,
# which renders for the VM, and the USB devices. With DEV_NETWORK=private, the
# command gets a network of its own instead of the host's, for servers that
# listen on every address, such as openQA's VNC.
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

# A device or socket, with its group: the developer may reach it only through
# the session's ACLs or the group, which the container doesn't carry.
groups_of() {
  for group in $(find "$1" -maxdepth 1 \( -type c -o -type b -o -type s \) -exec stat -c %g {} + | sort -u); do
    args+=(--group-add "$group")
  done
}
device() {
  [ -e "$1" ] || return 0
  args+=(--device "$1")
  groups_of "$1"
}
device /dev/kvm

# The host's engine. Docker's socket is its group's; rootful Podman's is
# root's, unless its service gives it a group (README.md).
# In the image, the Docker client, or Podman, which CONTAINER_HOST makes a
# client of the host's service.
case $ENGINE in
  docker)
    socket=${DOCKER_HOST:-unix:///var/run/docker.sock}
    args+=(-v "${socket#unix://}:/var/run/docker.sock" -e ENGINE=docker) ;;
  *podman*)
    socket=${CONTAINER_HOST:-unix:///run/podman/podman.sock}
    args+=(-v "${socket#unix://}:/run/engine.sock" -e ENGINE=podman -e CONTAINER_HOST=unix:///run/engine.sock) ;;
  *) echo "error: ENGINE=$ENGINE: expected docker or podman" >&2; exit 1 ;;
esac
socket=${socket#unix://}
[ -S "$socket" ] || { echo "error: $socket: no socket of ENGINE=$ENGINE (README.md)" >&2; exit 1; }
groups_of "$socket"

if [ "$1" = --desktop ]; then
  shift
  : "${XDG_RUNTIME_DIR:?}" "${WAYLAND_DISPLAY:?}"
  args+=(-v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR")
  pass XDG_RUNTIME_DIR WAYLAND_DISPLAY LANG
  device /dev/dri
  # USB devices, as they come and go, for a VM to borrow (DEVICES): QEMU opens
  # only those that this computer lets the developer open (README.md#devices).
  [ ! -d /dev/bus/usb ] || args+=(-v /dev/bus/usb:/dev/bus/usb --device-cgroup-rule 'c 189:* rwm')
fi

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
exec $ENGINE run "${args[@]}" "$DEV_IMAGE" "$@"
