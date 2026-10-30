#!/usr/bin/env bash
# Level 2: test the release medium MEDIUM itself, whole, as a person uses it, with
# isotovideo, openQA's test engine: enroll the key, install through the UI, boot,
# sign in, and so on (tests/openqa/main.pm). The medium is never written; the
# target disk and the TPM are new. Results stay in RESULTS/<time>-release, tied
# to the medium's checksum by provenance.json; a test that fails keeps its
# screenshots, and the medium's checksum is verified before anything starts.
# Usage: openqa.sh (called by `make test-release`).
set -euo pipefail
: "${ENGINE:?}" "${MEDIUM:?}" "${RESULTS:?}" "${SSH_KEY:?}" "${OWNER_NAME:?}" "${OPENQA_IMAGE:?}" "${OPENQA_DISTRI:?}" "${DISK_SIZE:?}" "${MEDIUM_SIZE:?}"
cd "$(dirname "$0")/.."

record=$MEDIUM.json
[[ -f $record ]] || { echo "error: $record not found; run 'make installer'" >&2; exit 1; }
read_record() { python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$record" "$1"; }
checksum=$(read_record medium_sha256)
if [[ $(sha256sum "$MEDIUM" | cut -d ' ' -f 1) != "$checksum" ]]; then
  echo "error: $MEDIUM differs from what was built" >&2
  exit 1
fi

run=$(realpath -m "$RESULTS/$(date -u +%Y%m%dT%H%M%SZ)-release")
mkdir -p "$run/pool"
pub=$(base64 -w0 <"$SSH_KEY.pub")
# The machine lives for this run, and so does its owner's password; vars.json,
# with it, stays with the results. Only letters and digits: the keys typed are
# the US layout's.
password=$(head -c 18 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')
# The firmware is the container's own: Microsoft's keys with Secure Boot on, as a factory PC.
cat >"$run/pool/vars.json" <<VARS
{
  "CASEDIR": "/distri",
  "PRODUCTDIR": "/distri",
  "NEEDLES_DIR": "/distri/needles",
  "DISTRI": "shapebit",
  "BACKEND": "qemu",
  "ARCH": "x86_64",
  "QEMU_NO_KVM": 0,
  "WORKER_INSTANCE": 1,
  "UEFI": 1,
  "UEFI_PFLASH_CODE": "/usr/share/qemu/ovmf-x86_64-smm-ms-code.bin",
  "UEFI_PFLASH_VARS": "/usr/share/qemu/ovmf-x86_64-smm-ms-vars.bin",
  "QEMUMACHINE": "q35,smm=on",
  "QEMUCPU": "host",
  "QEMUCPUS": 4,
  "QEMURAM": 4096,
  "QEMUTPM": 1,
  "QEMUTPM_PATH_PREFIX": "/pool/tpm",
  "QEMU_VIDEO_DEVICE": "virtio-vga",
  "XRES": 1280,
  "YRES": 800,
  "NUMDISKS": 2,
  "HDD_1": "/medium/installer.raw",
  "HDDSERIAL_1": "medium",
  "HDDSERIAL_2": "target",
  "QEMU_DISABLE_SNAPSHOTS": 1,
  "HDDSIZEGB_1": ${MEDIUM_SIZE%G},
  "STORAGE_KEEP_FREE_RATIO": 0.05,
  "STORAGE_KEEP_FREE_GB": 10,
  "HDDSIZEGB_2": ${DISK_SIZE%G},
  "BOOT_HDD_IMAGE": 1,
  "NICTYPE_USER_OPTIONS": "hostfwd=tcp::2222-:22",
  "QEMU_APPEND": "global driver=cfi.pflash01,property=secure,value=on -smbios type=11,value=io.systemd.credential.binary:ssh.authorized_keys.root=$pub",
  "NOVIDEO": 0,
  "OWNER_NAME": "$OWNER_NAME",
  "OWNER_PASSWORD": "$password",
  "IMAGE_DIGEST": "$(read_record image_digest)"
}
VARS

$ENGINE build -q -t "$OPENQA_IMAGE" -f tests/openqa/Containerfile tests/openqa >/dev/null
outcome=passed
# ENGINE is unquoted on purpose: it may be a command with arguments, e.g. "sudo podman".
$ENGINE run --rm --device /dev/kvm -w /pool \
  -v "$(realpath "$OPENQA_DISTRI"):/distri:ro,z" \
  -v "$(realpath "$MEDIUM"):/medium/installer.raw:ro,z" \
  -v "$(realpath "$SSH_KEY"):/ssh/key:ro,z" \
  -v "$run/pool:/pool:z" \
  -e LC_ALL=C.UTF-8 -e SSH_KEY=/ssh/key -e SSH_PORT=2222 -e OWNER_NAME="$OWNER_NAME" \
  "$OPENQA_IMAGE" -d 2>&1 | tee "$run/isotovideo.log" || outcome=failed

# The container wrote as root; the results are the caller's, and the machine's
# disks are not results.
$ENGINE run --rm -v "$run/pool:/pool:z" --entrypoint sh "$OPENQA_IMAGE" -c \
  "rm -rf /pool/raid /pool/tpm1 /pool/qemuscreenshot; chown -R $(id -u):$(id -g) /pool"

# isotovideo exits with 0 when a test module failed; its results say so.
python3 - "$run/pool/testresults" <<'PY' || outcome=failed
import json, pathlib, sys
modules = list(pathlib.Path(sys.argv[1]).glob("result-*.json"))
results = [json.loads(m.read_text()).get("result") for m in modules]
print(f"{len(results)} test modules: {results}")
sys.exit(not results or any(r != "ok" for r in results))
PY
python3 scripts/provenance.py run release-medium release "$outcome" "$run/provenance.json" "$record"
echo "$outcome: release (results in $run)"
[[ $outcome == passed ]]
