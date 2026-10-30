#!/usr/bin/env bash
# Run the checks of the container image inside it, with no network, keeping
# their output and the image's digest in RESULTS/<time>-image.
# Usage: check.sh (called by `make check`).
set -euo pipefail
: "${ENGINE:?}" "${IMAGE:?}" "${BUILD:?}" "${RESULTS:?}"
cd "$(dirname "$0")/.."
source scripts/results.sh

start_run image
python3 scripts/provenance.py image "$BUILD/image.tar" "$run/image.json"

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
$ENGINE run --rm --network none -v "$PWD/tests:/tests:ro,z" "$IMAGE" /tests/pytest.sh /tests/image 2>&1 |
  tee "$run/output.txt" || outcome=failed
finish_run container-image image "$run/image.json"
