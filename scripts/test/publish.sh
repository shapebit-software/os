#!/usr/bin/env bash
# Push the image archive ARCHIVE to the local update registry, starting the
# registry if needed. skopeo keeps its digest, so the system that updates from it
# reports the digest that the archive records. A VM switched to DEV_UPDATE_REF
# updates from it (tests/update/).
# Usage: publish.sh ARCHIVE [TAG]   TAG instead of DEV_UPDATE_REF's (`make test-update`).
set -euo pipefail
: "${ENGINE:?}" "${REGISTRY_PORT:?}" "${DEV_UPDATE_REF:?}"
archive=$1

# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
name=dev-registry
if [[ -z $($ENGINE ps -q --filter "name=^$name\$") ]]; then
  $ENGINE rm -f "$name" >/dev/null 2>&1 || true
  $ENGINE run -d --name "$name" -p "127.0.0.1:$REGISTRY_PORT:5000" docker.io/library/registry:2 >/dev/null
fi

# The host reaches the registry at localhost; the path and tag match DEV_UPDATE_REF.
ref=localhost:$REGISTRY_PORT/${DEV_UPDATE_REF#*/}
if [[ -n ${2:-} ]]; then
  ref=${ref%:*}:$2
fi
skopeo copy -q --preserve-digests --dest-tls-verify=false "oci-archive:$archive" "docker://$ref"
