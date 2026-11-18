#!/usr/bin/env bash
# Builds ShapeBit's own packages SPEC... in an image build, at the image's
# version and commit (IMAGE_VERSION, IMAGE_REVISION), with every time in them
# the commit's (SOURCE_DATE_EPOCH), so that a commit always gives the same
# packages (package.macros); copies them into OUT. Options for rpmbuild, such
# as a --define of what one spec needs, go before the specs.
# Usage: rpmbuild.sh OUT [RPMBUILD_OPTION...] SPEC...
#        (called by images/os/Containerfile and images/installer/Containerfile,
#        with this folder mounted)
set -euo pipefail
: "${IMAGE_VERSION:?}" "${IMAGE_REVISION:?}" "${SOURCE_DATE_EPOCH:?}"
export SOURCE_DATE_EPOCH
out=$1
shift

rpmbuild -bb --quiet --define "_topdir /tmp/rpm" --define "packages $(dirname "$(realpath "$0")")" \
  --define "image_version $IMAGE_VERSION" --define "image_revision $IMAGE_REVISION" "$@"
mkdir -p "$out"
cp /tmp/rpm/RPMS/*/*.rpm "$out/"
