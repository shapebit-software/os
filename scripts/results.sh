# The results of one test run, for the scripts that run tests to source. Run from
# the repository root.
# Usage: start_run NAME                  make the directory $run, in RESULTS, and
#                                        set $outcome to passed; a failed check
#                                        sets it to failed
#        finish_run KIND PLAN RECORD     write the run's provenance and report
#                                        the outcome; fails if the run did
: "${RESULTS:?}"

start_run() {
  run=$(realpath -m "$RESULTS/$(date -u +%Y%m%dT%H%M%SZ)-$1")
  mkdir -p "$run"
  outcome=passed
}

finish_run() {
  python3 scripts/provenance.py run "$1" "$2" "$outcome" "$run/provenance.json" "$3"
  echo "$outcome: $2 (results in $run)"
  [[ $outcome == passed ]]
}
