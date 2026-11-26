#!/usr/bin/python3
"""The license notices that some installed Fedora RPMs lack, taken from their
exact source RPMs into DESTDIR/usr/share/licenses/<package>/ (packages/licenses/README.md).

Shipping a component's notices is a condition of its license; these packages
leave some out. Each rule names the binary package, the archive in its source
RPM (or a tuple of archives, each inside the one before), the member in that
archive, and where the notice goes; a notice at the start of a source file
takes only that header. Texts that no source RPM of the package holds are
committed instead (COMMITTED), and the Makefile installs them. A wildcard matches one path
component, and exactly one member must match, or the build fails. Nothing from
an archive is extracted onto the filesystem. When Fedora ships a notice itself,
its rule goes. Runs in the image build; source RPMs stay in CACHE.
Usage: notices.py DESTDIR CACHE
       notices.py --licenses   print the licenses of the packages the
                                       rules are for, as one SPDX expression
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
    # exiv2-libs has no license text; its COPYING is only in exiv2, the command line tool.
    ('exiv2-libs', 'exiv2-*.tar.gz', 'exiv2-*/COPYING', 'exiv2-libs/COPYING', False),
    ('exiv2-libs', 'exiv2-*.tar.gz', 'exiv2-*/doc/COPYING-XMPSDK', 'exiv2-libs/COPYING-XMPSDK', False),
    ('glx-utils', 'mesa-demos-*.tar.xz', 'mesa-demos-*/src/xdemos/glxgears.c', 'glx-utils/NOTICE-glxgears', True),
    ('glx-utils', 'mesa-demos-*.tar.xz', 'mesa-demos-*/src/xdemos/glxinfo.c', 'glx-utils/NOTICE-glxinfo', True),
    ('mesa-libGLU', 'glu-*.tar.xz', 'glu-*/src/libtess/tess.c', 'mesa-libGLU/NOTICE-SGI', True),
    ('xcb-util-keysyms', 'xcb-util-keysyms-*.tar.xz', 'xcb-util-keysyms-*/COPYING', 'xcb-util-keysyms/COPYING', False),
    ('xorg-x11-server-Xwayland', 'xwayland-*.tar.xz', 'xwayland-*/COPYING', 'xorg-x11-server-Xwayland/COPYING', False),
    # Upstream COPYING is empty; CREDITS contains the per-sound authors and license assignments.
    ('sound-theme-freedesktop', 'sound-theme-freedesktop-*.tar.bz2', 'sound-theme-freedesktop-*/CREDITS', 'sound-theme-freedesktop/CREDITS', False),
    # malcontent-libs' COPYING is a link to this file, which only the source has.
    ('malcontent-libs', 'malcontent-*.tar.xz', 'malcontent-*/LICENSES/LGPL-2.1-or-later.txt', 'malcontent-libs/LICENSES/LGPL-2.1-or-later.txt', False),
    # These install no license text, and no package of their source that does is
    # in the image: the texts at the top of their sources.
    ('libbpf', 'v*.tar.gz', 'libbpf-*/LICENSE.BSD-2-Clause', 'libbpf/LICENSE.BSD-2-Clause', False),
    ('libbpf', 'v*.tar.gz', 'libbpf-*/LICENSE.LGPL-2.1', 'libbpf/LICENSE.LGPL-2.1', False),
    ('libosinfo', 'libosinfo-*.tar.xz', 'libosinfo-*/COPYING.LIB', 'libosinfo/COPYING.LIB', False),
    ('lsof', 'lsof-*.tar.xz', 'lsof-*/COPYING', 'lsof/COPYING', False),
    ('nss-altfiles', 'nss-altfiles-*.tar.gz', 'nss-altfiles-*/COPYING', 'nss-altfiles/COPYING', False),
    ('numactl-libs', 'numactl-*.tar.gz', 'numactl-*/LICENSE.LGPL2.1', 'numactl-libs/LICENSE.LGPL2.1', False),
    ('xfsprogs', 'xfsprogs-*.tar.xz', 'xfsprogs-*/LICENSES/GPL-2.0', 'xfsprogs/LICENSES/GPL-2.0', False),
    ('xfsprogs', 'xfsprogs-*.tar.xz', 'xfsprogs-*/LICENSES/LGPL-2.1', 'xfsprogs/LICENSES/LGPL-2.1', False),
    ('zlib-ng-compat', 'zlib-ng-*.tar.gz', 'zlib-ng-*/LICENSE.md', 'zlib-ng-compat/LICENSE.md', False),
    ('container-selinux', 'v*.tar.gz', 'container-selinux-*/LICENSE', 'container-selinux/LICENSE', False),
    ('WALinuxAgent-udev', 'v*.tar.gz', 'WALinuxAgent-*/LICENSE.txt', 'WALinuxAgent-udev/LICENSE.txt', False),
    ('WALinuxAgent-udev', 'v*.tar.gz', 'WALinuxAgent-*/NOTICE', 'WALinuxAgent-udev/NOTICE', False),
    # containers-common's settings come from the common, image and storage
    # projects of its source, all Apache-2.0; storage has a NOTICE.
    ('containers-common', 'v*.tar.gz', 'container-libs-common-*/common/LICENSE', 'containers-common/LICENSE', False),
    ('containers-common', 'v*.tar.gz', 'container-libs-common-*/storage/NOTICE', 'containers-common/NOTICE-storage', False),
    ('cdparanoia-libs', 'cdparanoia-III-*.src.tgz', 'cdparanoia-III-*/COPYING-LGPL', 'cdparanoia-libs/COPYING-LGPL', False),
    # Notices only in source headers: libdrm's MIT, libatasmart's LGPL.
    ('libdrm', 'libdrm-*.tar.xz', 'libdrm-*/xf86drm.c', 'libdrm/NOTICE', True),
    ('libatasmart', 'libatasmart-*.tar.xz', 'libatasmart-*/atasmart.c', 'libatasmart/NOTICE', True),
    # Intel's microcode license, which asks redistributors to reproduce it: in
    # Intel's archive, inside microcode_ctl's.
    ('microcode_ctl', ('microcode_ctl-*.tar.xz', 'microcode_ctl-*/microcode-*.tar.gz'),
     'Intel-Linux-Processor-Microcode-Data-Files-microcode-*/license', 'microcode_ctl/LICENSE-intel-ucode', False),
]

# The texts no source RPM of the package holds, one folder per package, each
# under the folder's name in /usr/share/licenses (packages/licenses/README.md):
# - shim-x64: shim's COPYRIGHT, BSD; its source RPM holds only the signed
#   binaries, whose code is shim-unsigned-x64's source (shim-16.1.tar.bz2).
# - ca-certificates: the GPL-2.0 that Fedora's License names, for its scripts,
#   which carry no notice; and the MPL-2.0 under which Mozilla publishes
#   certdata.txt, from which the trust store is made.
COMMITTED = pathlib.Path(__file__).parents[1] / "data/notices"


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


def comments(text):
    """The comments at the start of a C source, in order: /* */ blocks and runs
    of // lines, up to the first code."""
    while True:
        text = text.lstrip()
        if text.startswith("/*"):
            end = text.index("*/") + 2
            yield text[:end]
            text = text[end:]
        elif text.startswith("//"):
            lines = []
            for line in text.splitlines():
                if not line.startswith("//"):
                    break
                lines.append(line)
            yield "\n".join(lines)
            text = text[len("\n".join(lines)):]
        else:
            return


def header(data):
    """The first comment at the start of a source that has a copyright and its
    terms: a permission notice, or a license it is under."""
    for notice in comments(data.decode("utf-8")):
        lower = notice.lower()
        if "copyright" in lower and ("permission" in lower or "license" in lower or "licence" in lower):
            return (notice + "\n").encode()
    raise ValueError("source does not start with a copyright and permission notice")


def rpm_source(package, cache):
    name = subprocess.check_output(["rpm", "-q", "--qf", "%{SOURCERPM}", package], text=True).strip()
    if "/" in name or not name.endswith(".src.rpm"):
        raise ValueError(f"no source RPM for {package}: {name}")
    directory = cache / "rpms"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / name
    if not path.exists():
        # dnf uses the source repository metadata; Koji retains older versions
        # that have left the mirrors, as in distribution/sources/sources.py.
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


def nested(data, archives):
    """The innermost of ARCHIVES, each a member of the one before, in DATA."""
    for pattern in archives:
        data = member(data, pattern)
    return data


def collect(dest, cache, rules=RULES):
    root = dest / "usr/share/licenses"
    for package, archive, pattern, to, only_header in rules:
        outer, *inner = (archive,) if isinstance(archive, str) else archive
        text = member(nested(rpm_member(rpm_source(package, cache), outer), inner), pattern)
        place(root, to, header(text) if only_header else text)


def packages(rules=RULES, committed=COMMITTED):
    """The packages that this adds notices for, by a rule or a committed text."""
    folders = sorted(p.name for p in committed.iterdir() if p.is_dir())
    return list(dict.fromkeys([rule[0] for rule in rules] + folders))


def licenses(expressions):
    """One SPDX expression for all of EXPRESSIONS: each in parentheses when it
    has an operator, in order, and each only once."""
    unique = dict.fromkeys(e.strip() for e in expressions)
    return " AND ".join(e if " " not in e else f"({e})" for e in unique)


def main(args):
    if args == ["--licenses"]:
        query = subprocess.check_output(["rpm", "-q", "--qf", "%{LICENSE}\n", *packages()], text=True)
        print(licenses(query.splitlines()))
        return
    if len(args) != 2:
        raise ValueError(__doc__)
    collect(*map(pathlib.Path, args))


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"license collection failed: {error}")
