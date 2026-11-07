#!/usr/bin/env bash
# Pull the installer medium REF, from the os/installer package on GHCR, as MEDIUM
# and its record MEDIUM.json, and check it against the record; then MEDIUM is
# what `make -o installer disk` and `make test-release` test. The package is
# private: log in first with `skopeo login ghcr.io`.
# Usage: pull-installer.sh REF   e.g. ghcr.io/shapebit-software/os/installer:stable
set -euo pipefail
: "${BUILD:?}" "${MEDIUM:?}"
cd "$(dirname "$0")/.."
ref=$1

work=$BUILD/pulled-installer
rm -rf "$work"
trap 'rm -rf "$work"' EXIT
skopeo copy -q "docker://$ref" "oci:$work/layout"
python3 scripts/artifact.py unpack "$work/layout" "$work/files" shapebit-installer.img.xz shapebit-installer.img.json

xz -dc -T0 "$work/files/shapebit-installer.img.xz" >"$MEDIUM"
cp "$work/files/shapebit-installer.img.json" "$MEDIUM.json"
expected=$(python3 scripts/provenance.py field "$MEDIUM.json" medium_sha256)
echo "$expected  $MEDIUM" | sha256sum -c --quiet -
echo "Pulled installer $(python3 scripts/provenance.py field "$MEDIUM.json" version) from $ref"
