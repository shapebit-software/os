#!/usr/bin/env bash
# Run pytest with the checks' own dependencies, inside a container image or a
# guest, writing a JUnit report to the test's data directory (TMT_TEST_DATA).
# Usage: pytest.sh PYTEST_ARGUMENT...
set -euo pipefail
root=$(dirname "$(realpath "$0")")
export PYTHONPATH=$root/.deps:$root PYTHONDONTWRITEBYTECODE=1
report=()
if [[ -n ${TMT_TEST_DATA:-} ]]; then
  # A test that reboots runs once per boot; each run keeps its own report.
  report=("--junitxml=$TMT_TEST_DATA/junit-${TMT_REBOOT_COUNT:-0}.xml")
fi
exec python3 -m pytest -c "$root/pytest.ini" --rootdir="$root" -p no:cacheprovider "${report[@]}" "$@"
