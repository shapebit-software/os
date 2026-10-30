#!/usr/bin/env bash
# Publish the newer builds (scripts/update-builds.sh) to the local registry under
# their own tags, then run the update plan on a clone of the installed machine.
# Usage: update-test.sh (called by `make test-update`).
set -euo pipefail
: "${ENGINE:?}" "${IMAGE:?}" "${BUILD:?}"
cd "$(dirname "$0")/.."

for tag in next next2; do
  # ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
  $ENGINE load -q -i "$BUILD/image-$tag.tar" >/dev/null
  IMAGE="${IMAGE%:*}:$tag" scripts/publish.sh "$tag"
done
scripts/test-machine.sh update
