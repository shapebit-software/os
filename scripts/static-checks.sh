#!/usr/bin/env bash
# Check what the image would install, without building it: the desktop, the
# installer, the desktop's package list, and rootfs. Needs Fedora with the
# packages of distrobox.ini and the Hyprland COPR, as `make dev` or CI provides.
# Usage: static-checks.sh (called by `make static-checks`).
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
chmod 755 "$work"
trap 'rm -rf "$work"' EXIT

# Hyprland refuses to run as root, as a CI container is, and needs a runtime
# directory even to verify its configuration.
if ((EUID == 0)); then
  install -d -o nobody -m 700 "$work/runtime"
  setpriv --reuid=nobody --regid=nobody --clear-groups env HOME="$work/runtime" XDG_RUNTIME_DIR="$work/runtime" \
    make -C desktop check
else
  XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-$work} make -C desktop check
fi
make -C desktop install DESTDIR="$work/desktop"

cmake -S installer -B "$work/installer" -G Ninja
cmake --build "$work/installer"
ctest --test-dir "$work/installer" --output-on-failure

# Every package on the desktop's list still exists.
missing=0
for package in $(sed 's/#.*//' desktop/packages); do
  if [[ -z $(dnf -q repoquery --latest-limit=1 "$package" 2>/dev/null) ]]; then
    echo "error: desktop/packages: no package $package" >&2
    missing=1
  fi
done
exit_code=$missing

# rootfs's scripts parse.
while IFS= read -r file; do
  case $(head -n 1 "$file") in
    '#!'*bash* | '#!'*/sh*) bash -n "$file" || exit_code=1 ;;
    '#!'*python*) python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$file" || exit_code=1 ;;
  esac
done < <(find image/rootfs -type f -perm /111)

# Units parse. Their programs are in rootfs, not on this machine, so only
# syntax counts here; the image and system checks run them.
while IFS= read -r unit; do
  if systemd-analyze verify --man=no "$unit" 2>&1 | grep -E 'Unknown (key|section)|Failed to parse|Invalid'; then
    echo "error: $unit does not parse" >&2
    exit_code=1
  fi
done < <(find image/rootfs -type f \( -name '*.service' -o -name '*.timer' \))
exit "$exit_code"
