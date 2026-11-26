#!/usr/bin/env python3
"""Installs this tree's features into a running ShapeBit, to see a change on
the real system without building the image (README.md): every feature's
install rules, as the image's packages install them, but only what goes under
/usr; /etc and /var are machine state. MACHINE (quality/machine.py) is the
machine: the VM that `make vm` runs, reached over SSH; this computer, when it
runs ShapeBit, reached through the host's engine, which is root there
(dev.sh); or the simulator that `make simulate` runs (simulator/README.md).
There, sync-apply.sh makes the features that changed system extensions over
/usr, and refreshes the units of those features and of the features that
require them (their specs); the next boot drops the extensions, and so does
--reset, at once.

Usage: sync.py [--reset] (called by `make sync` or `make unsync`, in the
development image, with the settings the Makefile exports)."""

import io
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "quality"))
import machine  # noqa: E402

# The simulator's container (simulator/simulate.py).
SIMULATOR = "shapebit-simulator"


def stage(directory):
    """Each feature's /usr, from its install rules, in DIRECTORY/<feature>."""
    shutil.rmtree(directory, ignore_errors=True)
    for makefile in sorted((ROOT / "packages").glob("*/Makefile")):
        feature = makefile.parent.name
        subprocess.run(["make", "-s", "-C", makefile.parent, "install", f"DESTDIR={directory / feature}",
                        f"IMAGE_VERSION={machine.setting('IMAGE_VERSION')}",
                        f"IMAGE_REVISION={machine.setting('IMAGE_REVISION')}",
                        f"FEDORA={machine.setting('FEDORA_VERSION')}"], check=True)


def requires(feature):
    """The features that FEATURE's spec requires."""
    spec = next((ROOT / "packages" / feature).glob("*.spec"), None)
    return re.findall(r"^Requires:\s*shapebit-(\S+)", spec.read_text(), re.M) if spec else []


def archive(directory):
    """A tar of DIRECTORY's features, each its usr folder only, owned by root,
    and a list of the features it requires, `requires`."""
    def as_root(info):
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        return info

    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w") as tar:
        for feature in sorted(directory.iterdir()):
            if (feature / "usr").is_dir():
                tar.add(feature / "usr", f"{feature.name}/usr", filter=as_root)
                listing = "".join(f"{name}\n" for name in requires(feature.name)).encode()
                info = as_root(tarfile.TarInfo(f"{feature.name}/requires"))
                info.size = len(listing)
                tar.addfile(info, io.BytesIO(listing))
    return data.getvalue()


def command(script):
    """How to run SCRIPT as root on MACHINE: its argv."""
    target = machine.setting("MACHINE")
    if target == "vm":
        vm = machine.Machine(multiplex=False)
        return ["ssh", *vm.ssh_options(), f"root@{vm.address}", f"bash -c {shlex.quote(script)}"]
    if target == "local":
        # The host's engine is root on the host: a container in its process
        # namespace enters the host's namespaces, so the script runs there.
        return [*shlex.split(os.environ["ENGINE"]), "run", "--rm", "-i", "--privileged", "--pid=host",
                "--security-opt", "label=disable", os.environ["DEV_IMAGE"],
                "nsenter", "--target", "1", "--all", "bash", "-c", script]
    if target == "simulator":
        return [*shlex.split(os.environ["ENGINE"]), "exec", "-i", SIMULATOR, "bash", "-c", script]
    sys.exit(f"error: MACHINE={target}: expected vm, local, or simulator")


def main(reset=False):
    directory = machine.path("BUILD") / "sync"
    stage(directory)
    script = (ROOT / "development/sync-apply.sh").read_text()
    if reset:
        script = f"export SYNC_RESET=1\n{script}"
    # Every feature goes, for the units of those that require a changed one;
    # only PACKAGE's are laid over /usr, or taken away.
    if os.environ.get("PACKAGE"):
        script = f"export SYNC_PACKAGES={shlex.quote(os.environ['PACKAGE'])}\n{script}"
    if subprocess.run(command(script), input=archive(directory)).returncode:
        sys.exit("error: the machine did not take the tree; is it running ('make vm', or 'make simulate')?")


if __name__ == "__main__":
    main(reset=sys.argv[1:] == ["--reset"])
