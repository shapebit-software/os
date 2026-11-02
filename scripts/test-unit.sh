#!/usr/bin/env bash
# Run the tests that need no image and no VM: the Python unit tests and the
# installer's, then a trial install of the desktop. Needs Fedora with the packages
# of distrobox.ini and the Hyprland COPR, as `make dev` or CI provides.
# Usage: test-unit.sh (called by `make test-unit`).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VENV:?}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$VENV/bin/pytest" -c tests/pytest.ini --rootdir=tests -p no:cacheprovider tests/unit

cmake -S installer -B "$work/installer" -G Ninja
cmake --build "$work/installer"
ctest --test-dir "$work/installer" --output-on-failure

make -C desktop install DESTDIR="$work/desktop"
