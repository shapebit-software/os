#!/usr/bin/python3
"""The license notices that some installed Fedora RPMs lack, taken from their
exact source RPMs into DESTDIR/usr/share/licenses/<package>/ (docs/License.md).

Shipping a component's notices is a condition of its license; these packages
leave some out. Each rule names the binary package, the archive in its source
RPM, the member in that archive, and where the notice goes; a notice at the
start of a source file takes only that header. A wildcard matches one path
component, and exactly one member must match, or the build fails. Nothing from
an archive is extracted onto the filesystem. When Fedora ships a notice itself,
its rule goes. Runs in the image build; source RPMs stay in CACHE.
Usage: license-notices.py DESTDIR CACHE
"""

import fnmatch
import io
import pathlib
import subprocess
import sys
import tarfile
import urllib.request
import zipfile

# (package, archive in its source RPM, member, destination, header only)
RULES = [
    ('exiv2-libs', 'exiv2-*.tar.gz', 'exiv2-*/doc/COPYING-XMPSDK', 'exiv2-libs/COPYING-XMPSDK', False),
    ('glx-utils', 'mesa-demos-*.tar.xz', 'mesa-demos-*/src/xdemos/glxgears.c', 'glx-utils/NOTICE-glxgears', True),
    ('glx-utils', 'mesa-demos-*.tar.xz', 'mesa-demos-*/src/xdemos/glxinfo.c', 'glx-utils/NOTICE-glxinfo', True),
    ('mesa-libGLU', 'glu-*.tar.xz', 'glu-*/src/libtess/tess.c', 'mesa-libGLU/NOTICE-SGI', True),
    ('xcb-util-keysyms', 'xcb-util-keysyms-*.tar.xz', 'xcb-util-keysyms-*/COPYING', 'xcb-util-keysyms/COPYING', False),
    ('xorg-x11-server-Xwayland', 'xwayland-*.tar.xz', 'xwayland-*/COPYING', 'xorg-x11-server-Xwayland/COPYING', False),
    # Upstream COPYING is empty; CREDITS contains the per-sound authors and license assignments.
    ('sound-theme-freedesktop', 'sound-theme-freedesktop-*.tar.bz2', 'sound-theme-freedesktop-*/CREDITS', 'sound-theme-freedesktop/CREDITS', False),
    ('malcontent-libs', 'malcontent-*.tar.xz', 'malcontent-*/LICENSES/LGPL-2.1-or-later.txt', 'malcontent-libs/LICENSES/LGPL-2.1-or-later.txt', False),
]


def place(root, name, data):
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or not data.strip():
        raise ValueError(f"invalid or empty license material: {name}")
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return target


def matches_path(name, pattern):
    # A wildcard matches one path component, never a nested vendored project.
    parts, wanted = pathlib.PurePosixPath(name).parts, pathlib.PurePosixPath(pattern).parts
    return len(parts) == len(wanted) and all(fnmatch.fnmatchcase(p, w) for p, w in zip(parts, wanted))


def member(data, pattern):
    if zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            names = [n for n in archive.namelist() if matches_path(n, pattern) and not n.endswith("/")]
            if len(names) != 1:
                raise ValueError(f"expected one archive member for {pattern}, found {len(names)}")
            return archive.read(names[0])
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        matches = [m for m in archive if m.isfile() and matches_path(m.name, pattern)]
        if len(matches) != 1:
            raise ValueError(f"expected one archive member for {pattern}, found {len(matches)}")
        return archive.extractfile(matches[0]).read()


def header(data):
    text = data.decode("utf-8")
    if text.startswith("/*"):
        notice = text[: text.index("*/") + 2] + "\n"
    elif text.startswith("//"):
        lines = []
        for line in text.splitlines():
            if not line.startswith("//"):
                break
            lines.append(line)
        notice = "\n".join(lines) + "\n"
    else:
        raise ValueError("source does not start with a notice")
    if "copyright" not in notice.lower() or "permission" not in notice.lower():
        raise ValueError("source header has no copyright and permission notice")
    return notice.encode()


def rpm_source(package, cache):
    name = subprocess.check_output(["rpm", "-q", "--qf", "%{SOURCERPM}", package], text=True).strip()
    if "/" in name or not name.endswith(".src.rpm"):
        raise ValueError(f"no source RPM for {package}: {name}")
    directory = cache / "rpms"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / name
    if not path.exists():
        # dnf uses the source repository metadata; Koji retains older versions
        # that have left the mirrors, as in scripts/sources.py.
        subprocess.run(["dnf", "-q", "download", "--enablerepo=*-source", "--skip-unavailable",
                        "--destdir", str(directory), name.removesuffix(".src.rpm") + ".src"], check=False)
        if not path.exists():
            source, version, release = name.removesuffix(".src.rpm").rsplit("-", 2)
            url = f"https://kojipkgs.fedoraproject.org/packages/{source}/{version}/{release}/src/{name}"
            with urllib.request.urlopen(url, timeout=60) as response:
                path.write_bytes(response.read())
    actual = subprocess.check_output(["rpm", "-qp", "--qf", "%{NAME}-%{VERSION}-%{RELEASE}.src.rpm", str(path)])
    if actual.decode() != name:
        raise ValueError(f"wrong source RPM for {package}")
    return path


def rpm_member(path, pattern):
    data = subprocess.check_output(["rpm2cpio", str(path)])
    names = subprocess.check_output(["cpio", "-it", "--quiet"], input=data).decode().splitlines()
    matches = [n for n in names if fnmatch.fnmatchcase(n.removeprefix("./"), pattern)]
    if len(matches) != 1:
        raise ValueError(f"expected one source RPM member for {pattern}, found {len(matches)} in {names[:8]}")
    return subprocess.check_output(["cpio", "-i", "--to-stdout", "--quiet", matches[0]], input=data)


def collect(dest, cache, rules=RULES):
    root = dest / "usr/share/licenses"
    for package, archive, pattern, to, only_header in rules:
        text = member(rpm_member(rpm_source(package, cache), archive), pattern)
        place(root, to, header(text) if only_header else text)


def main(args):
    if len(args) != 2:
        raise ValueError(__doc__)
    collect(*map(pathlib.Path, args))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"license collection failed: {error}")
