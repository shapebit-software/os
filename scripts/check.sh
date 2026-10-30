#!/usr/bin/env bash
# Run the checks of the container image inside it, with no network, keeping
# their output and the image's digest in RESULTS/<time>-image.
# Usage: check.sh (called by `make check`).
set -euo pipefail
: "${ENGINE:?}" "${IMAGE:?}" "${BUILD:?}" "${RESULTS:?}"
cd "$(dirname "$0")/.."

run=$RESULTS/$(date -u +%Y%m%dT%H%M%SZ)-image
mkdir -p "$run"
python3 scripts/provenance.py image "$BUILD/image.tar" "$run/image.json"

outcome=passed
# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
$ENGINE run --rm --network none -v "$PWD/tests:/tests:ro,z" "$IMAGE" /tests/pytest.sh /tests/image 2>&1 |
  tee "$run/output.txt" || outcome=failed
python3 scripts/provenance.py run container-image image "$outcome" "$run/provenance.json" "$run/image.json"
echo "$outcome: image (results in $run)"
[[ $outcome == passed ]]
