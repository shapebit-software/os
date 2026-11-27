#!/usr/bin/env python3
"""The end-to-end tests (packages/testing/README.md): test the installer medium MEDIUM itself, whole,
as a person uses it, with isotovideo, openQA's test engine: enroll the key,
install, boot, sign in, and so on (main.pm). The medium is never written, and
its checksum is checked against its record first; the target disk and the TPM
are new. Results stay in RESULTS/<time>-release-FLOW; a module that fails
keeps its screenshots. It runs in the development image, with a network of
its own, as isotovideo's VNC server listens on every address. openQA reads
one folder of tests and one of needles: each run assembles them in its pool,
from this harness and each feature's tests/e2e/ (assemble).

Usage: run.py install           everything from the medium
       run.py update ARCHIVE    install, then update to ARCHIVE's build, which the
                                machine gets as an OCI layout, and test its desktop
"""

import base64
import hashlib
import json
import os
import pathlib
import secrets
import shutil
import string
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "src"))
from testing import machine as machines  # noqa: E402

# Large enough, and sparse, that the installer leaves the whole reserve beside
# the home (packages/homes/README.md), as on a real computer.
DISK_SIZE = "256G"
# The port that vars.json forwards to the machine's SSH.
SSH_PORT = "2222"


def assemble(case):
    """openQA's test distribution in CASE: main.pm and lib/ from here; each
    feature's packages/FEATURE/tests/e2e/ modules in tests/FEATURE/, and its
    needles, with those that several features share (needles/), in needles/.
    Two needles of one name fail: openQA would pick either."""
    shutil.copy(HERE / "main.pm", case / "main.pm")
    shutil.copytree(HERE / "lib", case / "lib", ignore=shutil.ignore_patterns("__pycache__"))
    needles = case / "needles"
    needles.mkdir()
    sources = [HERE / "needles"]
    for e2e in sorted(machines.ROOT.glob("packages/*/tests/e2e")):
        feature = e2e.parents[1].name
        (case / "tests" / feature).mkdir(parents=True)
        for module in e2e.glob("*.py"):
            shutil.copy(module, case / "tests" / feature / module.name)
        sources.append(e2e / "needles")
    for source in sources:
        for needle in sorted(source.glob("*")):
            if (needles / needle.name).exists():
                raise ValueError(f"{needle}: another feature has a needle of this name")
            shutil.copy(needle, needles / needle.name)


def run_vars(record, public_key, owner, medium_size, medium, pool, flow="install", update_digest=""):
    """The variables of a run, beside the fixed ones in vars.json. The sizes are
    in gigabytes, as `7G`; update needs the digest it moves to. The machine
    lives for this run, and so does its owner's password; vars.json, with it,
    stays with the results. Only letters and digits: the keys typed are the
    US layout's."""
    if flow not in ("install", "update") or (flow == "update") != bool(update_digest):
        raise ValueError(f"FLOW {flow!r} with UPDATE_DIGEST {update_digest!r}")
    credential = base64.b64encode(pathlib.Path(public_key).read_bytes()).decode()
    pool = pathlib.Path(pool)
    return json.loads((HERE / "vars.json").read_text()) | {
        "CASEDIR": str(pool / "case"),
        "PRODUCTDIR": str(pool / "case"),
        "NEEDLES_DIR": str(pool / "case" / "needles"),
        # The firmware of every test machine.
        "UEFI_PFLASH_CODE": machines.FIRMWARE_CODE,
        "UEFI_PFLASH_VARS": machines.FIRMWARE_VARS,
        "HDD_1": str(medium),
        "QEMUTPM_PATH_PREFIX": str(pool / "tpm"),
        "HDDSIZEGB_1": int(medium_size.removesuffix("G")),
        "HDDSIZEGB_2": int(DISK_SIZE.removesuffix("G")),
        "QEMU_APPEND": "global driver=cfi.pflash01,property=secure,value=on "
        f"-smbios type=11,value=io.systemd.credential.binary:ssh.authorized_keys.root={credential}",
        "OWNER_NAME": owner,
        "OWNER_PASSWORD": "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)),
        "IMAGE_DIGEST": json.loads(pathlib.Path(record).read_text())["image_digest"],
        "FLOW": flow,
    } | ({"UPDATE_DIGEST": update_digest, "CANDIDATE": str(pool / "candidate")} if flow == "update" else {})


def passed(testresults):
    """isotovideo exits with 0 when a test module failed; its results say so."""
    modules = pathlib.Path(testresults).glob("result-*.json")
    results = [json.loads(module.read_text()).get("result") for module in modules]
    print(f"{len(results)} test modules: {results}")
    return bool(results) and all(result == "ok" for result in results)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main(flow=None, *archive):
    if (flow, len(archive)) not in (("install", 0), ("update", 1)):
        sys.exit(__doc__)
    medium = machines.path("MEDIUM")
    record = medium.with_name(medium.name + ".json")
    if not record.exists():
        sys.exit(f"error: {record} not found; run 'make installer'")
    if sha256(medium) != machines.recorded(medium, "medium_sha256"):
        sys.exit(f"error: {medium} differs from what was built")

    run = machines.new_run(f"release-{flow}")
    pool = run / "pool"
    (pool / "case").mkdir(parents=True)
    assemble(pool / "case")
    update_digest = ""
    if flow == "update":
        update_digest = machines.archive_digest(archive[0])
        # A layout, as the installer's payload is: skopeo flattens Docker's
        # nested index, which bootc cannot read in a layout.
        subprocess.run(["skopeo", "copy", "-q", "--preserve-digests", f"oci-archive:{archive[0]}",
                        f"oci:{pool}/candidate"], check=True)
    key = machines.ssh_key()
    owner = machines.setting("OWNER_NAME")
    values = run_vars(record, f"{key}.pub", owner, machines.setting("MEDIUM_SIZE"), medium, pool, flow, update_digest)
    (pool / "vars.json").write_text(json.dumps(values, indent=2) + "\n")

    # isotovideo works in its pool; its output also goes to the results.
    env = os.environ | {"LC_ALL": "C.UTF-8", "SSH_KEY": str(key), "SSH_PORT": SSH_PORT, "OWNER_NAME": owner,
                        "PYTHONPATH": str(HERE.parent / "src")}
    with open(run / "isotovideo.log", "w") as log, \
            subprocess.Popen(["isotovideo", "-d"], cwd=pool, env=env, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, errors="replace") as engine:
        for line in engine.stdout:
            sys.stdout.write(line)
            log.write(line)
    # The machine's disks and the candidate are not results.
    for name in ("raid", "tpm1", "qemuscreenshot", "candidate"):
        shutil.rmtree(pool / name, ignore_errors=True)

    ok = passed(pool / "testresults") and engine.returncode == 0
    print(f"{'passed' if ok else 'failed'}: release-{flow} (results in {run})")
    sys.exit(not ok)


if __name__ == "__main__":
    main(*sys.argv[1:])
