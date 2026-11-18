#!/usr/bin/env bash
# Level 2: test the release medium MEDIUM itself, whole, as a person uses it, with
# isotovideo, openQA's test engine: enroll the key, install through the UI, boot,
# sign in, and so on (tests/openqa/main.pm). The medium is never written; the
# target disk and the TPM are new. Results stay in RESULTS/<time>-release; a
# test that fails keeps its screenshots, and the medium's checksum is verified
# before anything starts. FLOW=update also updates the installed system to
# UPDATE_ARCHIVE's build, which the machine gets as an OCI layout. It installs
# with an earlier installer and release, whose screens may look as they did:
# the needles of their commits, the record's revision and STABLE_REVISION, that
# differ go along (tests/openqa/run.py needles).
# It runs in the development image (images/development/Containerfile), with a network
# of its own, as isotovideo's VNC server listens on every address.
# Usage: openqa.sh (called by `make test-release`).
set -euo pipefail
: "${MEDIUM:?}" "${RESULTS:?}" "${SSH_KEY:?}" "${OWNER_NAME:?}" "${OPENQA_DISTRI:?}" "${OPENQA_DISK_SIZE:?}" "${MEDIUM_SIZE:?}" "${FLOW:?}"
cd "$(dirname "$0")/../.."
source tests/vm/results.sh

record=$MEDIUM.json
[[ -f $record ]] || { echo "error: $record not found; run 'make installer'" >&2; exit 1; }
checksum=$(python3 packages/installer/medium/provenance.py field "$record" medium_sha256)
if [[ $(sha256sum "$MEDIUM" | cut -d ' ' -f 1) != "$checksum" ]]; then
  echo "error: $MEDIUM differs from what was built" >&2
  exit 1
fi

start_run "release-$FLOW"
pool=$run/pool
mkdir "$pool"

update_digest= older=()
if [[ $FLOW == update ]]; then
  : "${UPDATE_ARCHIVE:?}"
  update_digest=$(python3 packages/installer/medium/provenance.py digest "$UPDATE_ARCHIVE")
  # A layout, as the installer's payload is: skopeo flattens Docker's nested
  # index, which bootc cannot read in a layout.
  skopeo copy -q --preserve-digests "oci-archive:$UPDATE_ARCHIVE" "oci:$pool/candidate"

  # A medium recorded before records had the revision has none.
  for revision in "$(python3 packages/installer/medium/provenance.py field "$record" revision '')" "${STABLE_REVISION:-}"; do
    directory=$pool/older/${revision:0:7}
    [[ -n $revision && ! -d $directory ]] || continue
    # A shallow checkout, as CI's, lacks the commit.
    git cat-file -e "$revision^{commit}" 2>/dev/null || git fetch -q --depth=1 origin "$revision"
    mkdir -p "$directory"
    # Earlier commits kept the needles in distribution/openqa/, image/openqa/, or tests/openqa/.
    for needles in "$OPENQA_DISTRI/needles" distribution/openqa/needles image/openqa/needles tests/openqa/needles; do
      git cat-file -e "$revision:$needles" 2>/dev/null && break
    done
    git archive "$revision:$needles" | tar -x -C "$directory"
    older+=("$directory")
  done
fi
python3 tests/openqa/run.py needles "$OPENQA_DISTRI/needles" "$pool/needles" "${older[@]}"
python3 tests/openqa/run.py vars "$record" "$SSH_KEY.pub" "$OWNER_NAME" "$MEDIUM_SIZE" "$OPENQA_DISK_SIZE" \
  "$(realpath "$OPENQA_DISTRI")" "$(realpath "$MEDIUM")" "$pool" "$FLOW" "$update_digest" "$pool/vars.json"

# isotovideo works in its pool; the port is the one vars.json forwards.
key=$(realpath "$SSH_KEY")
(cd "$pool" && LC_ALL=C.UTF-8 SSH_KEY=$key SSH_PORT=2222 isotovideo -d) 2>&1 | tee "$run/isotovideo.log" || outcome=failed

# The machine's disks and the candidate are not results.
rm -rf "$pool/raid" "$pool/tpm1" "$pool/qemuscreenshot" "$pool/candidate" "$pool/older" "$pool/needles"

python3 tests/openqa/run.py check "$pool/testresults" || outcome=failed
finish_run
