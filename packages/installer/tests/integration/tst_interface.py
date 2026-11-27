"""The installer's D-Bus interface, as installerctl uses it, against the
simulated backend on the session bus.
Usage: dbus-run-session -- python3 tst_interface.py BACKEND INSTALLERCTL (called by CTest)."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

backend, ctl = sys.argv[1:3]
work = pathlib.Path(tempfile.mkdtemp())
(work / "password").write_text("secret\n")
failed = False


def installerctl(*args):
    return subprocess.run([ctl, "--session", *args], capture_output=True, text=True)


def install(disk, user):
    return installerctl("install", "--disk", disk, "--user", user, "--password-file", str(work / "password"),
                        "--recovery-key-file", str(work / "key"))


def check(name, passed):
    global failed
    print(f"{'ok  ' if passed else 'FAIL'} {name}")
    failed |= not passed


server = subprocess.Popen([backend, "--simulate"], env=os.environ | {"INSTALLER_SIMULATE_STEP_MS": "20"})
try:
    while installerctl("capabilities").returncode:
        time.sleep(0.1)
    capabilities = json.loads(installerctl("capabilities").stdout)
    check("capabilities report a TPM2", capabilities.get("tpm2") is True)
    check("disks are listed", "wwn-0x5000000000000001" in installerctl("disks").stdout)
    check("locales are offered", "en_US.UTF-8" in capabilities.get("locales", []))
    check("networks are listed", '"ssid":"Simulated Home"' in installerctl("networks").stdout)
    check("a disk in use is refused", install("serial-SIM0003", "dev").returncode != 0)
    check("an invalid user name is refused", install("serial-SIM0002", "Root").returncode != 0)
    check("a failure is reported", install("serial-SIM0002", "fail").returncode != 0)
    installed = install("wwn-0x5000000000000001", "dev")
    check("an installation completes", installed.returncode == 0)
    check("every phase is reported in order", (installed.stdout + installed.stderr).split() == [
        "validating", "preparing", "creating-storage", "installing-system", "configuring", "verifying",
        "awaiting-acknowledgement"])
    key = work / "key"
    check("the recovery key is saved", key.exists() and "simulated-recovery-key" in key.read_text())
    check("the recovery key file is private", key.exists() and oct(key.stat().st_mode & 0o777) == "0o600")
finally:
    server.kill()
    subprocess.run(["rm", "-rf", str(work)])

sys.exit(1 if failed else 0)
