#!/usr/bin/env bash
# Install ShapeBit to the raw disk DISK of DISK_SIZE the way a user does: boot
# the installer medium MEDIUM in QEMU with the empty disk attached, and let the
# installer install to it. Saves the recovery key to RECOVERY_KEY.
# Usage: disk.sh           check the medium (the tmt plan "medium"), then install
#                          through installerctl, without the UI
#        disk.sh --window  open the VM in a window, to install by hand
set -euo pipefail
: "${BUILD:?}" "${RESULTS:?}" "${DISK:?}" "${DISK_SIZE:?}" "${MEDIUM:?}" "${RECOVERY_KEY:?}" "${OWNER_NAME:?}" "${OWNER_PASSWORD:?}" \
  "${LOCALE:?}" "${KEYBOARD_LAYOUT:?}" "${TIME_ZONE:?}"
cd "$(dirname "$0")/../.."
source tests/vm/results.sh

[[ -f $MEDIUM ]] || { echo "error: $MEDIUM not found; run 'make installer'" >&2; exit 1; }

# A new disk is a new machine: fresh EFI variables and TPM (see vm.sh).
rm -rf "$DISK" "$DISK.json" "$RECOVERY_KEY" "$BUILD/efivars.qcow2" "$BUILD/tpm" "$BUILD/serial.log"
truncate -s "$DISK_SIZE" "$DISK"

if [[ ${1:-} == --window ]]; then
  exec tests/vm/vm.sh --installer --window
fi

trap 'tests/vm/vm.sh --stop' EXIT
tests/vm/vm.sh --installer --background
IMAGE_DIGEST=$(python3 images/installer/provenance.py field "$MEDIUM.json" image_digest)
export IMAGE_DIGEST
start_run medium
tests/vm/tmt.sh medium "$run" || outcome=failed
finish_run

# The password and the recovery key stay in the VM's memory (/run). The small
# home leaves the disk to the system.
tests/vm/ssh.sh 'umask 077 && cat >/run/owner-password' <"$OWNER_PASSWORD"
tests/vm/ssh.sh installerctl install --disk serial-target --user "$OWNER_NAME" \
  --home-size $((1024 * 1024 * 1024)) \
  --locale "$LOCALE" --keyboard-layout "$KEYBOARD_LAYOUT" --time-zone "$TIME_ZONE" \
  --password-file /run/owner-password --recovery-key-file /run/recovery-key
(umask 077 && tests/vm/ssh.sh cat /run/recovery-key >"$RECOVERY_KEY")

# Powered off, so that the disk holds everything. A later build replaces the
# medium's record, so the disk keeps its own.
tests/vm/vm.sh --stop
trap - EXIT
cp "$MEDIUM.json" "$DISK.json"
