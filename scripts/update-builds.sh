#!/usr/bin/env bash
# Build the two newer images that the update test moves through, as IMAGE with
# the tags next and next2, saved beside the image as image-next.tar and
# image-next2.tar. IMAGE and its archive stay the build that was installed.
# Usage: update-builds.sh (called by `make update-builds`).
set -euo pipefail
: "${IMAGE:?}" "${IMAGE_VERSION:?}" "${BUILD:?}"
cd "$(dirname "$0")/.."

for tag in next next2; do
  make --no-print-directory image IMAGE="${IMAGE%:*}:$tag" \
    IMAGE_VERSION="$IMAGE_VERSION.$tag" IMAGE_ARCHIVE="$BUILD/image-$tag.tar"
done
