#!/usr/bin/env bash
# Update the system and roll it back, one stage per boot; tmt tells them apart
# by its reboot count. The first new build also runs the system's own checks,
# except the one that names the build that was installed.
# Usage: update.sh (called by tmt, as /update).
set -euo pipefail
case ${TMT_REBOOT_COUNT:?} in
  0)
    ../pytest.sh -m switched test_update.py
    tmt-reboot
    ;;
  1)
    ../pytest.sh -m updated test_update.py
    ../pytest.sh ../system -k 'not test_booted_the_image_under_test and not test_persistence'
    tmt-reboot
    ;;
  2)
    ../pytest.sh -m downloaded test_update.py
    tmt-reboot
    ;;
  3) ../pytest.sh -m rolled_back test_update.py ;;
  *) echo "error: unexpected reboot $TMT_REBOOT_COUNT" >&2; exit 1 ;;
esac
