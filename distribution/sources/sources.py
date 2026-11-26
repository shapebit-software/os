"""The source RPMs next to each published binary: that of every installed RPM,
whatever its license label says, as labels can be incomplete or use unfamiliar
names (distribution/sources/README.md). Reads the packages from IMAGE, and downloads their
source RPMs in a container of IMAGE, with dnf from Fedora's repositories, the
Hyprland COPR and ShapeBit's own, which the image ships (packages/repositories), or
from Fedora's Koji for a version that the repositories no longer have. Fails if any is missing. COPR deletes old
builds, so this runs right after a build, while the repositories still match.

collect() puts them in a directory, and write_tar() writes them as a tar that
the same files always give byte for byte. distribution/release.py calls them and
publishes what they make. ENGINE runs the containers.
"""

import os
import pathlib
import shlex
import shutil
import subprocess
import sys
import tarfile

TYPE = "application/vnd.shapebit.sources.v1"

# Runs in a container of the image, as root: the source repositories by exact
# NEVRA, then Koji for what they lack. The host checks what arrived. The
# repositories that the image ships turned off, its shapebit-repositories
# package's, are turned on by their ids, so a new one needs no change here.
DOWNLOAD = r"""
set -euo pipefail
cd /out
mapfile -t wanted <.wanted
mapfile -t ours < <(rpm -ql shapebit-repositories | grep '/repos\.d/.*\.repo$' | xargs sed -n 's/^\[\(.*\)\]$/\1/p')
ours+=('*-source')
repos=$(IFS=,; echo "${ours[*]}")
dnf -q -y download --enablerepo="$repos" --skip-unavailable --destdir /out "${wanted[@]/%/.src}" || true
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


def source_rpms(lines):
    """Every distinct source RPM, from `rpm -qa` lines of SOURCERPM and VENDOR;
    public keys have none. ShapeBit's own packages, built in the image build,
    are left out: their sources are this repository at the image's revision."""
    names = {line.split("\t")[0] for line in lines.splitlines() if not line.endswith("\tShapeBit")}
    return sorted(names - {"(none)", ""})


def image_source_rpms(image):
    query = "%{SOURCERPM}\t%{VENDOR}\n"
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
         "--entrypoint", "bash", image, "-s"],
        input=DOWNLOAD, text=True, check=True,
    )  # fmt: skip


def place(source, target):
    """A hard link where possible, else a copy: a source RPM can be large."""
    target.unlink(missing_ok=True)
    try:
        os.link(source, target)
    except OSError:
        shutil.copyfile(source, target)


def collect(image, directory, cache=None):
    """IMAGE's source RPMs in DIRECTORY, those in CACHE taken from there; their
    names, in order."""
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    names = image_source_rpms(image)
    for path in directory.glob("*.src.rpm"):
        if path.name not in names:
            path.unlink()
    for name in names:
        if not (directory / name).exists() and cache and (pathlib.Path(cache) / name).exists():
            place(pathlib.Path(cache) / name, directory / name)
    wanted = [name for name in names if not (directory / name).exists()]
    print(f"{len(names)} source RPMs; {len(names) - len(wanted)} at hand, {len(wanted)} to download")
    if wanted:
        download(image, directory, wanted)
    missing = [name for name in names if not (directory / name).exists()]
    if missing:
        sys.exit("error: no source for:\n  " + "\n  ".join(missing))
    size = sum((directory / name).stat().st_size for name in names)
    print(f"{len(names)} source RPMs, {size / 1e9:.2f} GB")
    return names


def add(directory, other):
    """Every source RPM in OTHER that DIRECTORY lacks, added to it: those of a
    medium that carries another image beside its own. Fails if OTHER has none."""
    directory, found = pathlib.Path(directory), sorted(pathlib.Path(other).glob("*.src.rpm"))
    if not found:
        sys.exit(f"error: no source RPMs in {other}")
    added = [path.name for path in found if not (directory / path.name).exists()]
    for name in added:
        place(pathlib.Path(other) / name, directory / name)
    return added


def write_tar(directory, out):
    """No times, owners, or modes from this machine, in the order of the names."""
    with tarfile.open(out, "w", format=tarfile.PAX_FORMAT) as tar:
        for path in sorted(pathlib.Path(directory).glob("*.src.rpm")):
            info = tarfile.TarInfo(path.name)
            info.size, info.mtime, info.mode = path.stat().st_size, 0, 0o644
            with open(path, "rb") as file:
                tar.addfile(info, file)
