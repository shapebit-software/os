#!/usr/bin/env bash
# Start the local update registry on 127.0.0.1:REGISTRY_PORT, unless it runs,
# with the host's engine; publish.sh pushes to it.
# Usage: registry.sh (called by `make registry`).
set -euo pipefail
: "${ENGINE:?}" "${REGISTRY_PORT:?}"

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
name=dev-registry
if [[ -z $($ENGINE ps -q --filter "name=^$name\$") ]]; then
  $ENGINE rm -f "$name" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$name" -p "127.0.0.1:$REGISTRY_PORT:5000" docker.io/library/registry:2 >/dev/null
fi
