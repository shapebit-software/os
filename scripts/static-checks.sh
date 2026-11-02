#!/usr/bin/env bash
# Lint and validate the repository, without building or running its code. Needs
# Fedora with the packages of distrobox.ini and the Hyprland COPR, as `make dev`
# or CI provides.
# Usage: static-checks.sh lint|validate (called by `make lint` and `make validate`).
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VENV:?}"

status=0

lint() {
  make -C desktop lint || status=1
  "$VENV/bin/tmt" --root tests lint >/dev/null || status=1

  # Every shell and Python file, by its extension or its first line. The openQA
  # tests are left out: their API comes from `from testapi import *`, so
  # pyflakes cannot tell which of its names exist.
  local shell=() python=() file first
  while IFS= read -r file; do
    first=
    IFS= read -r -n 100 first <"$file" || true
    case $file in
      *.sh) shell+=("$file") ;;
      *.py) python+=("$file") ;;
      *)
        case $first in
          '#!'*python*) python+=("$file") ;;
          '#!'*bash* | '#!'*/sh*) shell+=("$file") ;;
        esac
        ;;
    esac
  done < <(find . \( -name .git -o -name __pycache__ -o -path ./docs -o -path ./build -o -path ./installer/build \
    -o -path ./tests/.deps -o -path ./tests/openqa/tests \) -prune -o -type f -print)
  for file in "${shell[@]}"; do
    bash -n "$file" || status=1
  done
  "$VENV/bin/python" -m pyflakes "${python[@]}" || status=1
}

validate() {
  # Hyprland refuses to run as root, as a CI container is, and needs a runtime
  # directory even to verify its configuration.
  local runtime
  runtime=$(mktemp -d)
  if ((EUID == 0)); then
    chown nobody "$runtime"
    chmod 700 "$runtime"
    setpriv --reuid=nobody --regid=nobody --clear-groups env HOME="$runtime" XDG_RUNTIME_DIR="$runtime" \
      make -C desktop validate || status=1
  else
    XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-$runtime} make -C desktop validate || status=1
  fi
  rm -rf "$runtime"

  # Every package on the desktop's list still exists.
  local package unit
  for package in $(sed 's/#.*//' desktop/packages); do
    if [[ -z $(dnf -q repoquery --latest-limit=1 "$package" 2>/dev/null) ]]; then
      echo "error: desktop/packages: no package $package" >&2
      status=1
    fi
  done

  # Units parse. Their programs are in rootfs, not on this machine, so only
  # syntax counts here; the image and system checks run them.
  while IFS= read -r unit; do
    if systemd-analyze verify --man=no "$unit" 2>&1 | grep -E 'Unknown (key|section)|Failed to parse|Invalid'; then
      echo "error: $unit does not parse" >&2
      status=1
    fi
  done < <(find image/rootfs -type f \( -name '*.service' -o -name '*.timer' \))
}

case ${1:-} in
  lint) lint ;;
  validate) validate ;;
  *) echo "usage: $0 lint|validate" >&2; exit 2 ;;
esac
exit "$status"
