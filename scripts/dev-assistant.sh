#!/usr/bin/env bash
# Give `make run` (desktop/dev/run) what the assistant needs and the development
# container lacks: llama-server, copied out of the built image, and sherpa-onnx,
# which writes speech down, installed with pip in the container. Both go to
# $BUILD/dev, where `make run` looks for them. The models are not fetched here:
# `make run` downloads them for real, from Settings > Assistant, into
# $BUILD/dev/extras.
# Usage: dev-assistant.sh (called by `make dev-assistant` on the host, after `make image`).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ENGINE:?}" "${IMAGE:?}" "${BUILD:?}" "${DEV_ENTER:?}"

dev=$BUILD/dev
mkdir -p "$dev/llama" "$dev/extras"

container=$($ENGINE create "$IMAGE" true)
trap '$ENGINE rm "$container" >/dev/null' EXIT
$ENGINE cp "$container:/usr/libexec/llama/." "$dev/llama/"

# The versions the image has (desktop/dictation/requirements.txt), without its
# hashes, which are of the wheels for the image's Python.
packages=$(grep -o '^sherpa-onnx[a-z-]*==[0-9.]*' desktop/dictation/requirements.txt)
# shellcheck disable=SC2086 # Several words on purpose.
env $DEV_ENTER -- python3 -m pip install --quiet --upgrade --target "$dev/python" $packages

echo "The assistant's model server and speech engine are in $dev: now \`make run\` in desktop/."
