#!/usr/bin/env bash
# Runs make sync at once, then after every change in FOLDER... (default:
# packages/): changes that come while it runs wait in the pipe, and come
# together in the next.
# Usage: watch.sh [FOLDER...]   (called by make watch, with PACKAGE)
set -uo pipefail
(($#)) || set -- packages
make -s sync
inotifywait -mqr -e close_write,moved_to,create,delete --exclude '/__pycache__/|\.sw.$|~$' "$@" |
  while read -r _; do
    while read -t 0.3 -r _; do :; done
    make -s sync
  done
