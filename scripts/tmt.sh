#!/usr/bin/env bash
# Run a tmt plan on the machine already up on SSH_PORT, keeping everything it
# leaves in RUN_DIR: tmt's workdir, with logs, per-test data, and reports.
# Usage: tmt.sh PLAN RUN_DIR
set -euo pipefail
: "${VENV:?}" "${SSH_PORT:?}" "${SSH_KEY:?}"
: "${IMAGE_DIGEST:?}" "${IMAGE_VERSION:?}" "${OWNER_NAME:?}" "${LOCALE:?}" "${KEYBOARD_LAYOUT:?}" "${TIME_ZONE:?}" "${DEV_UPDATE_REF:?}"
plan=$1 run=$(realpath -m "$2")
mkdir -p "$run"

# tmt keeps its workdir at the same path on the guest, so it must be somewhere a
# guest can write, whatever the checkout's path: /var/tmp, not /home.
workdir=$(mktemp -d /var/tmp/shapebit-tmt.XXXXXX)
trap 'mv "$workdir" "$run/tmt"' EXIT

# tests/ is the tree that tmt copies to the guest, with its dependencies.
"$VENV/bin/tmt" --root tests run --id "$workdir" --scratch --all \
  --environment "IMAGE_DIGEST=$IMAGE_DIGEST IMAGE_VERSION=$IMAGE_VERSION OWNER_NAME=$OWNER_NAME" \
  --environment "LOCALE=$LOCALE KEYBOARD_LAYOUT=$KEYBOARD_LAYOUT TIME_ZONE=$TIME_ZONE" \
  --environment "DEV_UPDATE_REF=$DEV_UPDATE_REF" \
  plan --name "^/plans/$plan\$" \
  provision --how connect --guest "${TEST_GUEST:-127.0.0.1}" --port "$SSH_PORT" --key "$(realpath "$SSH_KEY")"
