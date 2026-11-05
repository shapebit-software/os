#!/usr/bin/env bash
# Download the installer medium of the latest ShapeBit release (or of TAG) into
# DIR, check it against the release's installer.img.json, and decompress it to
# DIR/installer.img. The medium is the "installer" artifact of the Candidate run
# that built the release's commit, so it needs `gh` signed in to GitHub, and it
# expires 30 days after that run.
# Usage: download-installer.sh [TAG] [DIR]   DIR defaults to installer-TAG.
set -euo pipefail

repo=shapebit-software/os
tag=${1:-$(gh release view -R "$repo" --json tagName --jq .tagName)}
dir=${2:-installer-$tag}

commit=$(gh release view "$tag" -R "$repo" --json body --jq .body |
  sed -n 's/^- Commit: `\([0-9a-f]\{40\}\)`$/\1/p')
[[ -n $commit ]] || { echo "error: release $tag names no commit" >&2; exit 1; }

run=$(gh run list -R "$repo" -w candidate.yml --commit "$commit" --status success \
  --json databaseId --jq '.[0].databaseId // empty')
[[ -n $run ]] || { echo "error: no successful Candidate run for $commit" >&2; exit 1; }

mkdir -p "$dir"
echo "Downloading the installer of $tag from run $run into $dir"
gh run download "$run" -R "$repo" -n installer -D "$dir"
gh release download "$tag" -R "$repo" -p installer.img.json -D "$dir" --clobber

echo "Decompressing"
xz -d -T0 -f "$dir/installer.img.xz"

expected=$(sed -n 's/.*"medium_sha256": *"\([0-9a-f]\{64\}\)".*/\1/p' "$dir/installer.img.json")
echo "$expected  $dir/installer.img" | sha256sum -c -
