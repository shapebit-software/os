#!/usr/bin/env python3
"""What scripts/openqa.sh needs around isotovideo: the variables of a run, and
its result. The variables that do not change are in vars.json.

Usage: run.py vars RECORD PUBLIC_KEY OWNER MEDIUM_SIZE DISK_SIZE OUT
       run.py check TESTRESULTS   fail unless every test module passed
"""

import base64
import json
import pathlib
import secrets
import string
import sys


def run_vars(record, public_key, owner, medium_size, disk_size):
    """The sizes are in gigabytes, as `14G`. The machine lives for this run, and so
    does its owner's password; vars.json, with it, stays with the results. Only
    letters and digits: the keys typed are the US layout's."""
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
    }


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
    elif command == "check":
        sys.exit(not passed(*args))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(*sys.argv[1:])
