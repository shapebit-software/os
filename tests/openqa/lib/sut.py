"""The system under test, as commands see it: pairs what the screen shows with
the state underneath. Access is the development SSH key that QEMU passes as a
systemd credential, as for every VM; nothing is baked into the medium."""

import json
import os
import shlex
import subprocess
import time

OWNER = os.environ["OWNER_NAME"]


def ssh(command):
    return subprocess.run(
        ["ssh", "-i", os.environ["SSH_KEY"], "-p", os.environ["SSH_PORT"],
         "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
         "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=5",
         "root@127.0.0.1", command],
        capture_output=True, text=True, encoding="utf-8",
    )  # fmt: skip


def run(command, check=True):
    done = ssh(command)
    if check and done.returncode != 0:
        raise AssertionError(f"{command}: {done.returncode}\n{done.stdout}\n{done.stderr}")
    return done.stdout


def wait_for_ssh(timeout=300):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if ssh("true").returncode == 0:
            return
        time.sleep(3)
    raise AssertionError(f"no SSH after {timeout}s")


def remove_medium(query_isotovideo):
    """What the installer asks of a person, "remove the USB drive", as far as a
    fixed virtio disk can: the firmware no longer boots it. Takes the engine's
    query function, which only the test modules can reach."""
    for device, index in (("hd0-device", -1), ("hd1-device", 0)):
        query_isotovideo("backend_execute_qmp_command", {"query": {
            "execute": "qom-set",
            "arguments": {"path": f"/machine/peripheral/{device}", "property": "bootindex", "value": index},
        }})  # fmt: skip


def as_owner(command, check=True):
    """Run a command in the owner's session."""
    uid = run(f"id -u {OWNER}").strip()
    inner = f"XDG_RUNTIME_DIR=/run/user/{uid} {command}"
    return run(f"setpriv --reuid={OWNER} --regid={OWNER} --init-groups sh -c {shlex.quote(inner)}", check)


def hyprctl_json(what):
    return json.loads(as_owner(f"hyprctl --instance 0 -j {what}"))


def wait_for(predicate, timeout=60):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(1)
    raise AssertionError(f"not true after {timeout}s: {predicate}")
