#!/usr/bin/env bash
# Builds the foundation image as FOUNDATION (image/README.md#foundation), or
# takes FOUNDATION_CACHE, a published one, when it was made from the same
# recipe. With --fresh, as Candidate builds it: from Fedora's latest bootc image,
# without the engine's cache, so that it has Fedora's updates.
# Usage: foundation.sh [--fresh] (called by make foundation)
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ENGINE:?}" "${FOUNDATION:?}" "${FEDORA_VERSION:?}"
fresh=${1:-}

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
label() { $ENGINE image inspect --format "{{index .Config.Labels \"software.shapebit.foundation.$2\"}}" "$1"; }

# Everything the foundation is made from, but Fedora's packages themselves: of
# the Containerfile, only its part before the development image.
recipe=$({
  echo "$FEDORA_VERSION"
  sed '/^# ---- The development image/,$d' image/Containerfile
  cat packages/repositories/system/{hyprland.repo,third-party.repo} packages/repositories/data/third-party.asc
  image/requires.sh
} | sha256sum | cut -d ' ' -f 1)

if [[ -z $fresh && -n ${FOUNDATION_CACHE:-} ]] && $ENGINE pull -q "$FOUNDATION_CACHE" >/dev/null 2>&1 &&
  [[ $(label "$FOUNDATION_CACHE" recipe) == "$recipe" ]]; then
  $ENGINE tag "$FOUNDATION_CACHE" "$FOUNDATION"
  exit 0
fi

# The bootc image by digest, which the OS image's packaging check compares with
# (Containerfile). The engine's copy is used until --fresh pulls.
base=quay.io/fedora/fedora-bootc:$FEDORA_VERSION
if [[ -n $fresh ]] || ! $ENGINE image inspect "$base" >/dev/null 2>&1; then
  $ENGINE pull -q "$base" >/dev/null
fi
base=$($ENGINE image inspect --format '{{index .RepoDigests 0}}' "$base")

# Without Docker's provenance attestation, which records the build's time: an
# unchanged foundation keeps its ID, so the development image stays cached.
BUILDX_NO_DEFAULT_ATTESTATIONS=1 $ENGINE build ${fresh:+--no-cache} --build-arg BASE="$base" --build-arg RECIPE="$recipe" \
  --target foundation -f image/Containerfile -t "$FOUNDATION" --build-context image=image packages
