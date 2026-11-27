#!/usr/bin/env python3
"""`make simulate` (README.md): the tree's desktop in a window on this
computer's display, on fake system services, apart from this computer: a
container of the development image, which has the OS's own packages, with no
network, a home folder of its own in BUILD, and the host's display only
through its Wayland socket. The tree goes in as `make sync` puts it into a
machine (development/sync.py), so `make watch MACHINE=simulator` keeps it up
to date; then session.sh runs the session, as the developer, until its window
closes.

Usage: simulate.py (called by `make simulate`, in the development image, with
the host's display; SCENARIO is a name in scenarios/)."""

import os
import pathlib
import shlex
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parents[1] / "packages" / "testing" / "src"))
from testing import machine  # noqa: E402
import sync  # noqa: E402

RUNTIME = f"/run/user/{os.getuid()}"


def engine(*args, **options):
    return subprocess.run([*shlex.split(os.environ["ENGINE"]), *args], **options)


def scenario():
    """The scenario's file, by its name in SCENARIO."""
    name = os.environ.get("SCENARIO") or "laptop"
    path = HERE / "scenarios" / f"{name}.toml"
    if not path.exists():
        names = ", ".join(sorted(p.stem for p in path.parent.glob("*.toml")))
        sys.exit(f"error: SCENARIO={name}: expected one of {names}")
    return path


def start(home):
    """The container, as root, which installs the tree; the developer's files,
    and their accounts, at the same paths as on the host."""
    uid, gid = os.getuid(), os.getgid()
    display = pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ["WAYLAND_DISPLAY"]
    args = ["run", "-d", "--rm", "--init", "--name", sync.SIMULATOR, "--network", "none",
            "--security-opt", "label=disable", "-v", f"{sync.ROOT}:{sync.ROOT}", "-v", f"{home}:{home}",
            "-v", "/etc/passwd:/etc/passwd:ro", "-v", "/etc/group:/etc/group:ro",
            "-v", f"{display}:/run/host-wayland", "--tmpfs", f"{RUNTIME}:mode=0700,uid={uid},gid={gid}"]
    # The GPU, with the groups that may use it.
    if pathlib.Path("/dev/dri").exists():
        args += ["--device", "/dev/dri"]
        for group in sorted({p.stat().st_gid for p in pathlib.Path("/dev/dri").iterdir()}):
            args += ["--group-add", str(group)]
    engine("rm", "-f", sync.SIMULATOR, capture_output=True)
    engine(*args, os.environ["DEV_IMAGE"], "sleep", "infinity", check=True, stdout=subprocess.DEVNULL)
    # Its session's settings, which also tell sync-apply.sh that this is the simulator.
    settings = f"SIMULATOR_USER={uid}\nSIMULATOR_GROUP={gid}\nHOME={home}\nXDG_RUNTIME_DIR={RUNTIME}\n"
    engine("exec", "-i", sync.SIMULATOR, "sh", "-c", "cat >/run/simulator", input=settings.encode(), check=True)


def main():
    path = scenario()
    home = machine.path("BUILD") / "simulator" / "home"
    home.mkdir(parents=True, exist_ok=True)
    start(home)
    try:
        os.environ["MACHINE"] = "simulator"
        sync.main()
        terminal = ["-t"] if sys.stdin.isatty() else []
        engine("exec", "-i", *terminal, "--user", f"{os.getuid()}:{os.getgid()}", "-w", str(sync.ROOT),
               "-e", f"HOME={home}", "-e", f"XDG_RUNTIME_DIR={RUNTIME}", "-e", "WAYLAND_DISPLAY=/run/host-wayland",
               sync.SIMULATOR, str(HERE / "session.sh"), str(path))
    finally:
        engine("rm", "-f", sync.SIMULATOR, capture_output=True)


if __name__ == "__main__":
    main()
