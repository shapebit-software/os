#!/usr/bin/env python3
"""What scripts/openqa.sh needs around isotovideo: the variables of a run, its
needles, and its result. The variables that do not change are in vars.json.

Usage: run.py vars RECORD PUBLIC_KEY OWNER MEDIUM_SIZE DISK_SIZE FLOW UPDATE_DIGEST OUT
       run.py needles NEEDLES OUT [OLDER...]   the run's needles, in OUT
       run.py check TESTRESULTS   fail unless every test module passed

FLOW is install or update (tests/openqa/main.pm); UPDATE_DIGEST is the digest of
the build that update moves to, and empty for install. OLDER are needle
directories of earlier commits, each named after its commit.
"""

import base64
import json
import pathlib
import secrets
import shutil
import string
import sys


def run_vars(record, public_key, owner, medium_size, disk_size, flow="install", update_digest=""):
    """The sizes are in gigabytes, as `7G`; update needs the digest it moves to.
    The machine lives for this run, and so does its owner's password; vars.json,
    with it, stays with the results. Only letters and digits: the keys typed are
    the US layout's."""
    if flow not in ("install", "update") or (flow == "update") != bool(update_digest):
        raise ValueError(f"FLOW {flow!r} with UPDATE_DIGEST {update_digest!r}")
    credential = base64.b64encode(pathlib.Path(public_key).read_bytes()).decode()
    static = pathlib.Path(__file__).with_name("vars.json").read_text()
    return json.loads(static) | {
        "HDDSIZEGB_1": int(medium_size.removesuffix("G")),
        "HDDSIZEGB_2": int(disk_size.removesuffix("G")),
        "QEMU_APPEND": "global driver=cfi.pflash01,property=secure,value=on "
        f"-smbios type=11,value=io.systemd.credential.binary:ssh.authorized_keys.root={credential}",
        "OWNER_NAME": owner,
        "OWNER_PASSWORD": "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)),
        "IMAGE_DIGEST": json.loads(pathlib.Path(record).read_text())["image_digest"],
        "FLOW": flow,
    } | ({"UPDATE_DIGEST": update_digest} if flow == "update" else {})


def needles(current, out, *older):
    """The tree's needles, and each of an older commit's that differs from the
    tree's, under its own tags and named after its commit: the update flow
    installs the stable release, whose screens may still look as they did at
    the commits it and its installer were built from."""
    current, out = pathlib.Path(current), pathlib.Path(out)
    shutil.copytree(current, out)
    for directory in map(pathlib.Path, older):
        for needle in sorted(directory.glob("*.json")):
            image = needle.with_suffix(".png")
            ours = current / needle.name
            if ours.exists() and ours.read_bytes() == needle.read_bytes() \
                    and ours.with_suffix(".png").read_bytes() == image.read_bytes():
                continue
            name = f"{needle.stem}-{directory.name}"
            shutil.copyfile(needle, out / f"{name}.json")
            shutil.copyfile(image, out / f"{name}.png")


def passed(testresults):
    """isotovideo exits with 0 when a test module failed; its results say so."""
    modules = pathlib.Path(testresults).glob("result-*.json")
    results = [json.loads(module.read_text()).get("result") for module in modules]
    print(f"{len(results)} test modules: {results}")
    return bool(results) and all(result == "ok" for result in results)


def main(command, *args):
    if command == "vars":
        *values, out = args
        pathlib.Path(out).write_text(json.dumps(run_vars(*values), indent=2) + "\n")
    elif command == "needles":
        needles(*args)
    elif command == "check":
        sys.exit(not passed(*args))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
