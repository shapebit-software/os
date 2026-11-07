#!/usr/bin/env python3
"""The sources that the GPL and its kin require next to each published binary:
the source RPM of every installed RPM whose license names a copyleft license
(docs/License.md). Reads the packages from IMAGE, and downloads their source
RPMs in a container of IMAGE, with dnf from Fedora's repositories and the
Hyprland COPR (image/hyprland.repo), or from Fedora's Koji for a version that
the repositories no longer have. Fails if any is missing. COPR deletes old
builds, so this runs right after a build, while the repositories still match.

Usage: sources.py collect IMAGE DIR [--cache DIR] [--previous REF]
           put IMAGE's source RPMs in DIR, taking those that the cache has, and
           print their total size and which are new since REF's sources
       sources.py push DIR REF TITLE   push DIR's source RPMs as an OCI artifact
       sources.py pull REF DIR         put the source RPMs of the artifact REF in DIR
       sources.py tar DIR FILE         write DIR's source RPMs as a tar: the same
                                       files always give the same bytes
ENGINE runs the containers; skopeo copies the artifacts.
"""

import argparse
import importlib.util
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TYPE = "application/vnd.shapebit.sources.v1"
# SPDX identifiers, and Fedora's older names such as GPLv2+.
COPYLEFT = re.compile(r"(?<![A-Za-z0-9])(?:AGPL|LGPL|GPL|MPL|EPL|CDDL)")

spec = importlib.util.spec_from_file_location("artifact", ROOT / "scripts/artifact.py")
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)

# Runs in a container of the image, as root: the source repositories by exact
# NEVRA, then Koji for what they lack. The host checks what arrived.
DOWNLOAD = r"""
set -euo pipefail
cd /out
mapfile -t wanted <.wanted
dnf -q download --enablerepo='*-source' --skip-unavailable --destdir /out "${wanted[@]/%/.src}" || true
missing=()
for nvr in "${wanted[@]}"; do [[ -f $nvr.src.rpm ]] || missing+=("$nvr"); done
if ((${#missing[@]})); then
  dnf -q -y install koji >/dev/null
  for nvr in "${missing[@]}"; do koji download-build --arch=src "$nvr" >/dev/null || true; done
fi
rm .wanted
chown -R "$OWNER" /out
"""


def engine():
    return shlex.split(os.environ["ENGINE"])


def copyleft(licenses):
    return any(COPYLEFT.search(license) for license in licenses)


def source_rpms(lines):
    """Which source RPMs to publish, from `rpm -qa` lines of SOURCERPM and LICENSE:
    those of which any binary package names a copyleft license."""
    licenses = {}
    for line in lines.splitlines():
        source, license = line.split("\t", 1)
        if source != "(none)":
            licenses.setdefault(source, set()).add(license)
    return sorted(source for source, names in licenses.items() if copyleft(names))


def image_source_rpms(image):
    query = "%{SOURCERPM}\t%{LICENSE}\n"
    lines = subprocess.run(
        [*engine(), "run", "--rm", "--network", "none", "--entrypoint", "rpm", image, "-qa", "--qf", query],
        check=True, capture_output=True, text=True,
    ).stdout  # fmt: skip
    return source_rpms(lines)


def download(image, directory, names):
    (directory / ".wanted").write_text("".join(name.removesuffix(".src.rpm") + "\n" for name in names))
    subprocess.run(
        [*engine(), "run", "--rm", "-i", "-e", f"OWNER={os.getuid()}:{os.getgid()}",
         "-v", f"{directory.resolve()}:/out:z",
         "-v", f"{ROOT / 'image/hyprland.repo'}:/etc/yum.repos.d/hyprland.repo:ro,z",
         "--entrypoint", "bash", image, "-s"],
        input=DOWNLOAD, text=True, check=True,
    )  # fmt: skip


def previous_names(ref):
    """The source RPMs of an earlier artifact, from its manifest alone."""
    done = subprocess.run(["skopeo", "inspect", "--raw", f"docker://{ref}"], capture_output=True, text=True)
    if done.returncode != 0:
        return None
    layers = json.loads(done.stdout).get("layers", [])
    return {layer.get("annotations", {}).get(artifact.TITLE) for layer in layers}


def collect(image, directory, cache=None, previous=None):
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    names = image_source_rpms(image)
    for path in directory.glob("*.src.rpm"):
        if path.name not in names:
            path.unlink()
    for name in names:
        if not (directory / name).exists() and cache and (pathlib.Path(cache) / name).exists():
            artifact.place(pathlib.Path(cache) / name, directory / name)
    wanted = [name for name in names if not (directory / name).exists()]
    print(f"{len(names)} source RPMs; {len(names) - len(wanted)} at hand, {len(wanted)} to download")
    if wanted:
        download(image, directory, wanted)
    missing = [name for name in names if not (directory / name).exists()]
    if missing:
        sys.exit("error: no source for:\n  " + "\n  ".join(missing))
    size = sum((directory / name).stat().st_size for name in names)
    print(f"{len(names)} source RPMs, {size / 1e9:.2f} GB")
    if previous:
        before = previous_names(previous)
        if before is None:
            print(f"{previous}: none to compare with")
        else:
            new = [name for name in names if name not in before]
            print(f"{len(new)} new since {previous}:", *new, sep="\n  ")


def push(directory, ref, title):
    directory = pathlib.Path(directory)
    files = sorted(str(path) for path in directory.glob("*.src.rpm"))
    if not files:
        sys.exit(f"error: no source RPMs in {directory}")
    with tempfile.TemporaryDirectory(dir=directory.parent) as work:
        layout = pathlib.Path(work) / "layout"
        artifact.pack(layout, TYPE, title, files)
        subprocess.run(["skopeo", "copy", "-q", "--preserve-digests", f"oci:{layout}", f"docker://{ref}"], check=True)


def pull(ref, directory):
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory.parent) as work:
        layout = pathlib.Path(work) / "layout"
        subprocess.run(["skopeo", "copy", "-q", f"docker://{ref}", f"oci:{layout}"], check=True)
        artifact.unpack(layout, directory)


def write_tar(directory, out):
    """No times, owners, or modes from this machine, in the order of the names."""
    with tarfile.open(out, "w", format=tarfile.PAX_FORMAT) as tar:
        for path in sorted(pathlib.Path(directory).glob("*.src.rpm")):
            info = tarfile.TarInfo(path.name)
            info.size, info.mtime, info.mode = path.stat().st_size, 0, 0o644
            with open(path, "rb") as file:
                tar.addfile(info, file)


def main(argv):
    sys.stdout.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser(usage=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("collect")
    command.add_argument("image")
    command.add_argument("directory")
    command.add_argument("--cache")
    command.add_argument("--previous")
    command = commands.add_parser("push")
    command.add_argument("directory")
    command.add_argument("ref")
    command.add_argument("title")
    command = commands.add_parser("pull")
    command.add_argument("ref")
    command.add_argument("directory")
    command = commands.add_parser("tar")
    command.add_argument("directory")
    command.add_argument("out")
    args = parser.parse_args(argv)
    if args.command == "collect":
        collect(args.image, args.directory, args.cache, args.previous)
    elif args.command == "push":
        push(args.directory, args.ref, args.title)
    elif args.command == "pull":
        pull(args.ref, args.directory)
    else:
        write_tar(args.directory, args.out)


if __name__ == "__main__":
    main(sys.argv[1:])
