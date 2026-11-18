#!/usr/bin/env bash
# Check that every package that ShapeBit's packages require still
# exists, in the image's Fedora version and ShapeBit's third-party repository,
# before an image build would find out. The query reads only metadata, so it
# needs no key. Requires with a macro are the specs' own (see distribution/image/Containerfile).
# Usage: requires.sh (called by `make validate`, in Fedora, as `make dev`).
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${FEDORA_VERSION:?}"

status=0
third_party=$(sed -n 's/^baseurl=//p' packages/repositories/third-party.repo | head -1)
# Every package of the image: a spec at the top of a feature folder (the
# installer's is only on the medium), and what it requires that is not ours.
for spec in $(ls packages/*/*.spec | grep -v '^packages/installer/'); do
  for package in $(sed -n 's/^Requires: *//p' "$spec" | grep -v -e '%{' -e '^shapebit-'); do
    if [[ -z $(dnf -q repoquery --releasever="$FEDORA_VERSION" --latest-limit=1 \
      --repofrompath="third-party,$third_party" --setopt=third-party.repo_gpgcheck=0 \
      "$package" 2>/dev/null) ]]; then
      echo "error: $spec: no package $package" >&2
      status=1
    fi
  done
done
exit "$status"
