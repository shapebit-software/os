#!/usr/bin/env bash
# Run a tmt plan on a disposable clone of the installed machine, then discard
# the clone. The clone has its own disk overlay, EFI variables, and TPM: the
# installed disk unlocks only with the TPM it was sealed to, so all three go
# together, and the installed disk itself is never written. Results stay in
# RESULTS/<time>-<plan>, tied to the disk by provenance.json.
# Usage: test-machine.sh PLAN
set -euo pipefail
: "${BUILD:?}" "${DISK:?}" "${RESULTS:?}" "${TEST_SSH_PORT:?}" "${VENV:?}" "${RECOVERY_KEY:?}"
plan=$1
cd "$(dirname "$0")/.."
source scripts/results.sh

record=$DISK.json
[[ -f $record ]] || { echo "error: $record not found; run 'make disk'" >&2; exit 1; }
IMAGE_DIGEST=$(python3 scripts/provenance.py field "$record" image_digest)
export IMAGE_DIGEST

start_run "$plan"
machine=$run/machine
mkdir -p "$machine"
qemu-img create -q -f qcow2 -F raw -b "$(realpath "$DISK")" "$machine/disk.qcow2"
cp "$BUILD/efivars.fd" "$machine/efivars.fd"
cp -a "$BUILD/tpm" "$machine/tpm"
export BUILD=$machine DISK=$machine/disk.qcow2 DISK_FORMAT=qcow2 SSH_PORT=$TEST_SSH_PORT

finish() {
  scripts/vm.sh --stop
  # What the machine printed stays; the machine does not.
  mv "$machine/serial.log" "$run/" 2>/dev/null || true
  rm -rf "$machine"
}
trap finish EXIT
scripts/vm.sh --background

scripts/tmt.sh "$plan" "$run" || outcome=failed
if [[ $plan == system ]]; then
  "$VENV/bin/pytest" -c tests/pytest.ini --rootdir=tests -p no:cacheprovider \
    --junitxml="$run/junit-host.xml" tests/host || outcome=failed
fi
finish_run installed-disk "$plan" "$record"
