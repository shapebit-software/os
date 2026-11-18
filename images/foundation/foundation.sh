#!/usr/bin/env bash
# Builds the foundation image as FOUNDATION (images/README.md#foundation), or
# takes FOUNDATION_CACHE, a published one, when it was made from the same
# recipe. With --fresh, as Candidate builds it: from Fedora's latest bootc image,
# without the engine's cache, so that it has Fedora's updates.
# Usage: foundation.sh [--fresh] (called by make foundation)
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ENGINE:?}" "${FOUNDATION:?}" "${FEDORA_VERSION:?}"
fresh=${1:-}

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
label() { $ENGINE image inspect --format "{{index .Config.Labels \"software.shapebit.foundation.$2\"}}" "$1"; }

# Everything the foundation is made from, but Fedora's packages themselves.
recipe=$({
  echo "$FEDORA_VERSION"
  cat images/foundation/Containerfile packages/repositories/{hyprland.repo,third-party.repo,third-party.asc}
  packages/requires.sh
} | sha256sum | cut -d ' ' -f 1)

if [[ -z $fresh && -n ${FOUNDATION_CACHE:-} ]] && $ENGINE pull -q "$FOUNDATION_CACHE" >/dev/null 2>&1 &&
  [[ $(label "$FOUNDATION_CACHE" recipe) == "$recipe" ]]; then
  $ENGINE tag "$FOUNDATION_CACHE" "$FOUNDATION"
  exit 0
fi

# The bootc image by digest, which the OS image's packaging check compares with
# (images/os/Containerfile). The engine's copy is used until --fresh pulls.
base=quay.io/fedora/fedora-bootc:$FEDORA_VERSION
if [[ -n $fresh ]] || ! $ENGINE image inspect "$base" >/dev/null 2>&1; then
  $ENGINE pull -q "$base" >/dev/null
fi
base=$($ENGINE image inspect --format '{{index .RepoDigests 0}}' "$base")

$ENGINE build ${fresh:+--no-cache} --build-arg BASE="$base" --build-arg RECIPE="$recipe" \
  --build-context packages=packages -f images/foundation/Containerfile -t "$FOUNDATION" images/foundation
