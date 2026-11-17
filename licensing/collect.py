#!/usr/bin/python3
"""Collect the notices that installed RPMs lack, from their exact source RPMs,
and link RPM-owned license files kept outside /usr/share/licenses into it.

Fixed license texts are committed under image/rootfs/usr/share/licenses and
desktop/extras/licenses; this handles only what depends on the installed
packages or compiled sources. Nothing from an archive is extracted onto the
filesystem. Usage:
  collect.py collect RULES DESTDIR CACHE
  collect.py header SOURCE DESTINATION
"""

import fnmatch
import hashlib
import io
import json
import pathlib
import re
import subprocess
import sys
import tarfile
import urllib.request
import zipfile


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


def rpm_links(root, documents):
    """Link license files from outside /usr/share/licenses without moving them:
    those RPM marks as %license, those named like one under /usr/share (many
    packages, such as the X11 libraries, ship theirs as plain documents), and
    the listed documents that hold license text under another name."""
    query = "[%{=NAME}\t%{FILENAMES}\t%{FILEFLAGS:fflags}\n]"
    for line in subprocess.check_output(["rpm", "-qa", "--qf", query], text=True).splitlines():
        package, name, flags = line.split("\t")
        source = pathlib.Path(name)
        if name.startswith("/usr/share/licenses/"):
            continue
        text_suffix = source.suffix.lower() in {"", ".txt", ".md", ".rst", ".html", ".gz", ".bz2", ".xz",
                                               ".gpl", ".lgpl", ".bsd", ".mit", ".apache", ".ofl", ".mpl", ".ucd"}
        document = (name.startswith("/usr/share/") and text_suffix and re.fullmatch(
            r"(?:.*[-_])?(?:copying|copyright|licen[cs]e|notice|credits)(?:[._-].*)?", source.name, re.IGNORECASE))
        if "l" not in flags and not (source.is_file() and (document or name in documents)):
            continue
        if not source.is_file() or not source.read_bytes().strip():
            raise ValueError(f"missing RPM license: {name}")
        target = root / package / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if target.read_bytes() == source.read_bytes():
                continue
            target = target.with_name(target.name + "-" + hashlib.sha256(source.read_bytes()).hexdigest()[:12])
        if not target.is_symlink():
            target.symlink_to(source)


def collect(rules, dest, cache):
    spec = json.loads(rules.read_text())
    root = dest / "usr/share/licenses"
    for source in spec["rpms"]:
        path = rpm_source(source["package"], cache)
        for rule in source["files"]:
            text = member(rpm_member(path, rule["archive"]), rule["member"])
            place(root, rule["to"], header(text) if rule.get("header") else text)
    rpm_links(root, spec["documents"])


def main(args):
    if args[:1] == ["header"] and len(args) == 3:
        source, target = map(pathlib.Path, args[1:])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(header(source.read_bytes()))
    elif args[:1] == ["collect"] and len(args) == 4:
        collect(*map(pathlib.Path, args[1:]))
    else:
        raise ValueError(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"license collection failed: {error}")
