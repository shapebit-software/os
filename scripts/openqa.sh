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
# Usage: openqa.sh (called by `make test-release`).
set -euo pipefail
: "${ENGINE:?}" "${MEDIUM:?}" "${RESULTS:?}" "${SSH_KEY:?}" "${OWNER_NAME:?}" "${OPENQA_IMAGE:?}" "${OPENQA_DISTRI:?}" "${OPENQA_DISK_SIZE:?}" "${MEDIUM_SIZE:?}" "${FLOW:?}" "${FEDORA_VERSION:?}"
cd "$(dirname "$0")/.."
source scripts/results.sh

record=$MEDIUM.json
[[ -f $record ]] || { echo "error: $record not found; run 'make installer'" >&2; exit 1; }
checksum=$(python3 scripts/provenance.py field "$record" medium_sha256)
if [[ $(sha256sum "$MEDIUM" | cut -d ' ' -f 1) != "$checksum" ]]; then
  echo "error: $MEDIUM differs from what was built" >&2
  exit 1
fi

start_run "release-$FLOW"
mkdir "$run/pool"

$ENGINE build -q --build-arg FEDORA_VERSION="$FEDORA_VERSION" -t "$OPENQA_IMAGE" -f tests/openqa/Containerfile tests/openqa >/dev/null
# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
update_digest= candidate=() older=()
if [[ $FLOW == update ]]; then
  : "${UPDATE_ARCHIVE:?}"
  update_digest=$(python3 scripts/provenance.py digest "$UPDATE_ARCHIVE")
  # A layout, as the installer's payload is: skopeo flattens Docker's nested
  # index, which bootc cannot read in a layout.
  mkdir "$run/pool/candidate"
  $ENGINE run --rm --entrypoint skopeo \
    -v "$(realpath "$UPDATE_ARCHIVE"):/image.tar:ro,z" -v "$run/pool/candidate:/candidate:z" \
    "$OPENQA_IMAGE" copy -q --preserve-digests oci-archive:/image.tar oci:/candidate
  candidate=(-v "$run/pool/candidate:/candidate:ro,z")

  # A medium recorded before records had the revision has none.
  for revision in "$(python3 scripts/provenance.py field "$record" revision '')" "${STABLE_REVISION:-}"; do
    directory=$run/pool/older/${revision:0:7}
    [[ -n $revision && ! -d $directory ]] || continue
    # A shallow checkout, as CI's, lacks the commit.
    git cat-file -e "$revision^{commit}" 2>/dev/null || git fetch -q --depth=1 origin "$revision"
    mkdir -p "$directory"
    git archive "$revision:$OPENQA_DISTRI/needles" | tar -x -C "$directory"
    older+=("$directory")
  done
fi
python3 tests/openqa/run.py needles "$OPENQA_DISTRI/needles" "$run/pool/needles" "${older[@]}"
python3 tests/openqa/run.py vars "$record" "$SSH_KEY.pub" "$OWNER_NAME" "$MEDIUM_SIZE" "$OPENQA_DISK_SIZE" \
  "$FLOW" "$update_digest" "$run/pool/vars.json"

$ENGINE run --rm --device /dev/kvm -w /pool \
  -v "$(realpath "$OPENQA_DISTRI"):/distri:ro,z" -v "$run/pool/needles:/distri/needles:ro,z" \
  -v "$(realpath "$MEDIUM"):/medium/installer.img:ro,z" \
  -v "$(realpath "$SSH_KEY"):/ssh/key:ro,z" \
  -v "$run/pool:/pool:z" "${candidate[@]}" \
  -e LC_ALL=C.UTF-8 -e SSH_KEY=/ssh/key -e SSH_PORT=2222 -e OWNER_NAME="$OWNER_NAME" \
  "$OPENQA_IMAGE" -d 2>&1 | tee "$run/isotovideo.log" || outcome=failed

# The container wrote as root; the results are the caller's, and the machine's
# disks and the candidate are not results.
$ENGINE run --rm -v "$run/pool:/pool:z" --entrypoint sh "$OPENQA_IMAGE" -c \
  "rm -rf /pool/raid /pool/tpm1 /pool/qemuscreenshot /pool/candidate /pool/older /pool/needles; chown -R $(id -u):$(id -g) /pool"

python3 tests/openqa/run.py check "$run/pool/testresults" || outcome=failed
finish_run
