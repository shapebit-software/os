# The results of one test run, for the scripts that run tests to source. Run from
# the repository root.
# Usage: start_run NAME                  make the directory $run, in RESULTS, and
#                                        set $outcome to passed; a failed check
#                                        sets it to failed
#        finish_run                      report the outcome; fails if the run did
: "${RESULTS:?}"

start_run() {
  run=$(realpath -m "$RESULTS/$(date -u +%Y%m%dT%H%M%SZ)-$1")
  mkdir -p "$run"
  outcome=passed
  run_name=$1
}

finish_run() {
  echo "$outcome: $run_name (results in $run)"
  [[ $outcome == passed ]]
}
