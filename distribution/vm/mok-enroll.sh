#!/usr/bin/env bash
# Enroll the image's certificate on the VM that vm.sh just started, as a person
# does on a new PC's first boot of the medium: shim refuses systemd-boot and
# opens its MOK manager; there, Enroll key from disk, enroll-this-key.cer,
# Continue, Yes, Reboot. Keys go to QEMU's monitor; the screens are read from
# the serial console.
# Usage: mok-enroll.sh (called by vm.sh)
set -euo pipefail
: "${BUILD:?}" "${BOOT_TIMEOUT:?}"
serial=$BUILD/serial.log
offset=0

# Waits for TEXT on the console since the last keys, then sends KEY...
step() {
  local text=$1 deadline=$((SECONDS + BOOT_TIMEOUT))
  shift
  until tail -c "+$((offset + 1))" "$serial" | grep -qa "$text"; do
    if ((SECONDS >= deadline)); then
      echo "error: no '$text' on the console after ${BOOT_TIMEOUT}s" >&2
      exit 1
    fi
    sleep 1
  done
  sleep 1
  offset=$(stat -c %s "$serial")
  for key in "$@"; do
    echo "sendkey $key" >"$BUILD/monitor.in"
    sleep 1
  done
}

step 'Verification failed' ret
step 'Press any key' ret
step 'Perform MOK management' down ret
# The partition, then the certificate: the last entry, after EFI/ and loader/.
step 'Select Key' ret
step 'enroll-this-key.cer' down down ret
step 'View key 0' down ret
step 'Enroll the key' down ret
step 'Reboot' ret
