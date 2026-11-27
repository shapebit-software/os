#!/usr/bin/env bash
# Lints every shell, Python and Rust file in FOLDER... (default: the repository), by
# its extension or its first line; a file with a #! line must be executable.
# openQA's modules are left out: their API comes from `from testapi import *`,
# so pyflakes cannot tell which of its names exist. Rust files must be as
# rustfmt formats them (rustfmt.toml, beside this script or in data/).
# Usage: lint.sh [FOLDER...]   (called by make lint)
set -uo pipefail
status=0 python=() rust=()
while IFS= read -r file; do
  [ -f "$file" ] || continue
  first=$(head -c 100 "$file" | head -n 1 | tr -d '\0')
  case $first in '#!'*) [ -x "$file" ] || { echo "error: $file has a #! line but is not executable" >&2; status=1; } ;; esac
  case $file:$first in
    *.sh:* | *:'#!'*bash* | *:'#!'*/sh*) bash -n "$file" || status=1 ;;
    *.py:* | *:'#!'*python*) grep -q '^from testapi import' "$file" || python+=("$file") ;;
    *.rs:*) rust+=("$file") ;;
    # QML's JavaScript engine lacks some of the language's newer functions.
    *.qml:* | *.js:*) ! grep -Hn 'Object\.fromEntries' "$file" ||
      { echo "error: $file: QML's JavaScript has no Object.fromEntries" >&2; status=1; } ;;
  esac
done < <(git ls-files -co --exclude-standard "$@")
python3 -m pyflakes "${python[@]}" || status=1
# Rust's formatting rules: beside this script once installed, else this tree's.
config=$(dirname "$0")/rustfmt.toml
[[ -f $config ]] || config=$(dirname "$0")/../data/rustfmt.toml
((${#rust[@]} == 0)) || rustfmt --check --edition 2024 --config-path "$config" "${rust[@]}" || status=1
exit $status
