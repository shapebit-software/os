#!/usr/bin/env bash
# Fails when an external package's License tag, in FOLDER... (default: every
# feature), is not on Fedora's list of licenses. ShapeBit's brand terms are
# not, so its own packages are left out.
# Usage: check-licenses.sh [FOLDER...]   (called by make validate)
set -uo pipefail
(($#)) || set -- packages/*
status=0
for sources in $(git ls-files "${@/%//external/*/sources}"); do
  spec=$(dirname "$sources")/$(basename "$(dirname "$sources")").spec
  license-validate "$(rpmspec -q --srpm --qf '%{LICENSE}' "$spec")" >/dev/null ||
    { echo "error: $spec: License is not on Fedora's list" >&2; status=1; }
done
exit $status
