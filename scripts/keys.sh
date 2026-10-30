#!/usr/bin/env bash
# Generate the development signing key in KEYS_DIR (dev.key, dev.crt). One key
# does every job: it fills Secure Boot's PK, KEK, and db, and signs systemd-boot,
# the UKI, and the UKI's expected PCR 11 values. Separate keys protect only when
# they are stored apart, and these are all kept together.
# Usage: keys.sh (called by `make`; an existing key is kept).
set -euo pipefail
: "${KEYS_DIR:?}"

mkdir -p "$KEYS_DIR"
[[ -f $KEYS_DIR/dev.crt ]] && exit 0
openssl req -quiet -new -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -subj "/CN=ShapeBit development/" \
  -keyout "$KEYS_DIR/dev.key" -out "$KEYS_DIR/dev.crt"
