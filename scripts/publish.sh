#!/usr/bin/env bash
# Push IMAGE to the local update registry, starting the registry if needed.
# A VM switched to DEV_UPDATE_REF updates from it (tests/update.sh).
# Usage: publish.sh (called by `make publish` and tests/update.sh).
set -euo pipefail
: "${ENGINE:?}" "${IMAGE:?}" "${REGISTRY_PORT:?}" "${DEV_UPDATE_REF:?}"

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
name=dev-registry
if [[ -z $($ENGINE ps -q --filter "name=^$name\$") ]]; then
  $ENGINE rm -f "$name" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$name" -p "127.0.0.1:$REGISTRY_PORT:5000" docker.io/library/registry:2 >/dev/null
fi

# The host reaches the registry at localhost; the path and tag match DEV_UPDATE_REF.
ref=localhost:$REGISTRY_PORT/${DEV_UPDATE_REF#*/}
push_args=()
if $ENGINE push --help | grep -q -- --tls-verify; then
  push_args=(--tls-verify=false)
fi
$ENGINE tag "$IMAGE" "$ref"
$ENGINE push "${push_args[@]}" "$ref"
