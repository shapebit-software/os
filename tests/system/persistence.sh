#!/usr/bin/env bash
# What survives a reboot: checks the state left before it, in two stages that
# tmt tells apart by its reboot count.
# Usage: persistence.sh (called by tmt, as /system/persistence).
set -euo pipefail
case ${TMT_REBOOT_COUNT:?} in
  0)
    ../pytest.sh -m before_reboot test_persistence.py
    tmt-reboot
    ;;
  1) ../pytest.sh -m after_reboot test_persistence.py ;;
  *) echo "error: unexpected reboot $TMT_REBOOT_COUNT" >&2; exit 1 ;;
esac
