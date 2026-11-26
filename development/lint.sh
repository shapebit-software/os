#!/usr/bin/env bash
# Lints every shell and Python file in FOLDER... (default: the repository), by
# its extension or its first line; a file with a #! line must be executable.
# openQA's modules are left out: their API comes from `from testapi import *`,
# so pyflakes cannot tell which of its names exist.
# Usage: lint.sh [FOLDER...]   (called by make lint)
set -uo pipefail
status=0 python=()
while IFS= read -r file; do
  [ -f "$file" ] || continue
  first=$(head -c 100 "$file" | head -n 1 | tr -d '\0')
  case $first in '#!'*) [ -x "$file" ] || { echo "error: $file has a #! line but is not executable" >&2; status=1; } ;; esac
  case $file:$first in
    *.sh:* | *:'#!'*bash* | *:'#!'*/sh*) bash -n "$file" || status=1 ;;
    *.py:* | *:'#!'*python*) grep -q '^from testapi import' "$file" || python+=("$file") ;;
  esac
done < <(git ls-files -co --exclude-standard "$@")
python3 -m pyflakes "${python[@]}" || status=1
exit $status
