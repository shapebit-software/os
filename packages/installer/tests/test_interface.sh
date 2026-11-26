#!/usr/bin/env bash
# Run installerctl against the simulated backend on the session bus.
# Usage: dbus-run-session -- interface.sh BACKEND INSTALLERCTL (called by ctest).
set -euo pipefail
backend=$1 ctl=$2

work=$(mktemp -d)
INSTALLER_SIMULATE_STEP_MS=20 "$backend" --simulate &
trap 'kill $!; rm -rf "$work"' EXIT
until "$ctl" --session capabilities >/dev/null 2>&1; do sleep 0.1; done

failed=0
check() {
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; failed=1; fi
}
install() {
  "$ctl" --session install --disk "$1" --user "$2" \
    --password-file "$work/password" --recovery-key-file "$work/key" >"$work/log" 2>&1
}

echo secret >"$work/password"
check "capabilities report a TPM2" sh -c "'$ctl' --session capabilities | grep -q '\"tpm2\":true'"
check "disks are listed" sh -c "'$ctl' --session disks | grep -q wwn-0x5000000000000001"
check "locales are offered" sh -c "'$ctl' --session capabilities | grep -q '\"locales\":\[.*en_US.UTF-8'"
check "networks are listed" sh -c "'$ctl' --session networks | grep -q '\"ssid\":\"Simulated Home\"'"
check "a disk in use is refused" sh -c "! '$ctl' --session install --disk serial-SIM0003 --user dev \
  --password-file '$work/password' --recovery-key-file '$work/key' 2>/dev/null"
check "an invalid user name is refused" sh -c "! '$ctl' --session install --disk serial-SIM0002 --user Root \
  --password-file '$work/password' --recovery-key-file '$work/key' 2>/dev/null"
check "a failure is reported" sh -c "! '$ctl' --session install --disk serial-SIM0002 --user fail \
  --password-file '$work/password' --recovery-key-file '$work/key' 2>/dev/null"
check "an installation completes" install wwn-0x5000000000000001 dev
check "every phase is reported in order" test "$(tr '\n' ' ' <"$work/log")" = \
  "validating preparing creating-storage installing-system configuring verifying awaiting-acknowledgement "
check "the recovery key is saved" grep -q simulated-recovery-key "$work/key"
check "the recovery key file is private" test "$(stat -c %a "$work/key")" = 600

exit "$failed"
