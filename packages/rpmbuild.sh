#!/usr/bin/env bash
# Builds ShapeBit's own packages SPEC... in an image build, at the image's
# version and commit (IMAGE_VERSION, IMAGE_REVISION), with every time in them
# the commit's (SOURCE_DATE_EPOCH), so that a commit always gives the same
# packages (package.macros); copies them into OUT. Options for rpmbuild, such
# as a --define of what one spec needs, go before the specs.
# Usage: rpmbuild.sh OUT [RPMBUILD_OPTION...] SPEC...
#        (called by the Containerfile, its os, licenses and installer stages,
#        with this folder mounted)
set -euo pipefail
: "${IMAGE_VERSION:?}" "${IMAGE_REVISION:?}" "${SOURCE_DATE_EPOCH:?}"
export SOURCE_DATE_EPOCH
out=$1
shift

# One rpmbuild for each spec: in one for several, a spec's BuildArch would
# carry over to the specs after it, and a noarch one make the next noarch.
options=() specs=()
for arg in "$@"; do
  if [[ $arg == *.spec ]]; then specs+=("$arg"); else options+=("$arg"); fi
done
for spec in "${specs[@]}"; do
  rpmbuild -bb --quiet --define "_topdir /tmp/rpm" --define "packages $(dirname "$(realpath "$0")")" \
    --define "image_version $IMAGE_VERSION" --define "image_revision $IMAGE_REVISION" "${options[@]}" "$spec"
done
mkdir -p "$out"
cp /tmp/rpm/RPMS/*/*.rpm "$out/"
