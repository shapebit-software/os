#!/usr/bin/env bash
# Push the image archive ARCHIVE to the local update registry, which
# registry.sh started. skopeo keeps its digest, so the system that updates from
# it reports the digest that the archive records. A VM switched to
# DEV_UPDATE_REF updates from it (tests/checks/update/).
# Usage: publish.sh ARCHIVE [TAG]   TAG instead of DEV_UPDATE_REF's (`make test-update`).
set -euo pipefail
: "${REGISTRY_PORT:?}" "${DEV_UPDATE_REF:?}"
archive=$1

# The host reaches the registry at localhost; the path and tag match DEV_UPDATE_REF.
ref=localhost:$REGISTRY_PORT/${DEV_UPDATE_REF#*/}
if [[ -n ${2:-} ]]; then
  ref=${ref%:*}:$2
fi
skopeo copy -q --preserve-digests --dest-tls-verify=false "oci-archive:$archive" "docker://$ref"
