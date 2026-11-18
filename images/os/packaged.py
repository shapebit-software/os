#!/usr/bin/python3
"""Every file the image adds to /usr belongs to an RPM, as the RPM has it, so
that its license, sources and SBOM entry come with it, and `rpm -V` finds what
changed (packages/licenses/README.md).

Fedora's bootc base image already has files that no RPM owns (its kernel
modules, firmware, rpm-ostree's own files) and files that differ from their
RPMs (GRUB's, removed; Python's caches); `list` records both in a build stage of
the base, and `check` fails the image build on any other. Left out: the caches
that tools generate from installed files (GENERATED), what packages mark as
generated (%ghost), /etc and /var, which are the machine's, /run, and
modification times, which bootc images set to the same time for all files. The
kernel's version is left out of paths, so the base's kernel and the image's
compare.
Usage: packaged.py list             print what under /usr no RPM has as it is
       packaged.py check BASE       fail unless all of it is in BASE or CHANGED
"""

import os
import re
import subprocess
import sys

# Written by the tools that index what packages install: fontconfig's, the
# desktop files', GTK's and shared-mime-info's caches (not mime/packages/, which
# packages install), and rpm's own database. Regular expressions of whole paths.
GENERATED = [
    r"/usr/lib/fontconfig/cache/[^/]+",
    r"(/usr|/usr/local)/share/applications/mimeinfo\.cache",
    r"/usr/share/icons/[^/]+/icon-theme\.cache",
    r"/usr/share/mime/(?!packages/)[^/]+/[^/]+\.xml",
    r"/usr/share/rpm/[^/]+",
]

# Changes that the build makes on purpose, each with the reason for it, as
# `rpm -V` lines without the attribute column.
CHANGED = {
    # The boot splash is ShapeBit's (images/os/Containerfile); plymouth reads its
    # theme from here before the system's /etc exists.
    "..5...... /usr/share/plymouth/plymouthd.defaults",
    # Fedora's onnxruntime links libonnxruntime.so.1 to an OpenVINO build that it
    # does not install; ldconfig links it to the library that is installed.
    "....L.... /usr/lib64/libonnxruntime.so.1",
}


def normalized(path):
    return re.sub(r"^/usr/lib/modules/[^/]+/", "/usr/lib/modules/KERNEL/", path)


def unowned(owned, paths):
    """PATHS that are not in OWNED, kernel version left out."""
    owned = set(owned)
    return sorted({normalized(p) for p in paths if p not in owned})


def files(root="/usr"):
    """Every file and symbolic link under ROOT; directories need no owner."""
    for directory, directories, names in os.walk(root):
        for name in names + [d for d in directories if os.path.islink(os.path.join(directory, d))]:
            yield os.path.join(directory, name)


def changed(lines):
    """`rpm -Va --nomtime` LINES of paths under /usr that differ from their
    packages, without the attribute column and %ghost files."""
    found = set()
    for line in lines:
        match = re.fullmatch(r"(\S+) +(\S)? +(/.*)", line)
        if not match:
            continue
        result, attribute, path = match.groups()
        if attribute == "g" or not path.startswith("/usr/"):
            continue
        found.add(f"{result} {normalized(path)}")
    return sorted(found)


def unexpected(found, base):
    """FOUND paths and changes that are neither in BASE, GENERATED, nor CHANGED."""
    base = set(base)
    return [p for p in found
            if p not in base and p not in CHANGED and not any(re.fullmatch(g, p) for g in GENERATED)]


def found():
    owned = subprocess.run(["rpm", "-qa", "--qf", "[%{FILENAMES}\n]"],
                           check=True, capture_output=True, text=True).stdout.splitlines()
    # rpm -V exits non-zero when anything differs; that is what is read here.
    verified = subprocess.run(["rpm", "-Va", "--nomtime"], capture_output=True, text=True).stdout.splitlines()
    return unowned(owned, files()) + changed(verified)


def main(args):
    if args == ["list"]:
        print("\n".join(found()))
    elif len(args) == 2 and args[0] == "check":
        with open(args[1]) as base:
            extra = unexpected(found(), base.read().splitlines())
        if extra:
            sys.exit("files that no RPM owns, or that differ from their RPM:\n  " + "\n  ".join(extra))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
