"""The installer medium (README.md#steps): the released OS that it carries,
the built medium and its sources pushed to os/installer, the files that the
download server publishes, and a published medium pulled for the tests."""

import json
import lzma
import pathlib
import shutil
import subprocess
import sys
import tempfile

from common import INSTALLERS, REPOSITORY, VERSION_LABEL, copy, exists, image_label, log, push_sources, stdout_to_stderr
import archive
import oci
import sources

INSTALLER_TYPE = "application/vnd.shapebit.installer.v1"
MEDIUM_FILE, RECORD_FILE = "shapebit-installer.img.xz", "shapebit-installer.img.json"
SOURCES_TAR = "shapebit-installer-sources.tar"


def stable(image_archive, sources_dir):
    """The released OS that an installer carries, pinned by digest so that a
    release meanwhile cannot change what is built; there is one installer per
    OS version. Its sources save downloading most of the installer's."""
    image = f"{REPOSITORY}@{oci.registry_digest(f'{REPOSITORY}:stable')}"
    version = image_label(image, VERSION_LABEL)
    if exists(f"{INSTALLERS}:{version}"):
        sys.exit(f"error: {INSTALLERS}:{version} exists: there is one installer per OS version; release a new one first")
    with stdout_to_stderr():
        pathlib.Path(image_archive).parent.mkdir(parents=True, exist_ok=True)
        copy(f"docker://{image}", f"oci-archive:{image_archive}")
        oci.pull(f"{REPOSITORY}:{version}-sources", sources_dir)
    print(f"IMAGE={image}\nVERSION={version}")


def installer(version, installer_image, medium, os_sources):
    """A built medium, compressed, with its record, and its sources, to
    os/installer. The sources are those of everything on the medium: the
    installer's, and those of the OS it carries (OS_SOURCES), whose own
    published sources are pruned long before the medium is replaced
    (channel.prune). The record gets their tar's SHA-256, which the download
    server checks."""
    medium = pathlib.Path(medium)
    work = medium.parent / "installer-release"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir()
    sources.collect(installer_image, work / "sources", cache=os_sources)
    added = sources.add(work / "sources", os_sources)
    log(f"{len(added)} source RPMs of the OS it carries, beyond the installer's")
    sources.write_tar(work / "sources", work / SOURCES_TAR)
    record_path = medium.with_name(medium.name + ".json")
    record = json.loads(record_path.read_text()) | {"sources_sha256": archive.sha256(work / SOURCES_TAR)}
    record_path.write_text(json.dumps(record, indent=2) + "\n")
    shutil.copyfile(record_path, work / RECORD_FILE)
    with open(work / MEDIUM_FILE, "wb") as out:
        subprocess.run(["xz", "-T0", "-c", medium], stdout=out, check=True)
    oci.push(f"{INSTALLERS}:{version}", INSTALLER_TYPE, f"ShapeBit installer {version}", [work / MEDIUM_FILE, work / RECORD_FILE])
    push_sources(work / "sources", f"{INSTALLERS}:{version}-sources", f"ShapeBit installer {version}: sources")


def installer_files(version, directory):
    """What the download server publishes, as it names them: the medium, its
    record, and its sources as the tar again, byte for byte, as the record says."""
    directory = pathlib.Path(directory)
    oci.pull(f"{INSTALLERS}:{version}", directory)
    with tempfile.TemporaryDirectory(dir=directory.parent) as work:
        oci.pull(f"{INSTALLERS}:{version}-sources", work)
        sources.write_tar(work, directory / SOURCES_TAR)
    expected = json.loads((directory / RECORD_FILE).read_text())["sources_sha256"]
    if archive.sha256(directory / SOURCES_TAR) != expected:
        sys.exit(f"error: {SOURCES_TAR} differs from the record")


def pull_installer(ref, medium):
    """A published medium as MEDIUM, and its record as MEDIUM.json, checked
    against the record; then MEDIUM is what the machines test. The package is
    private: log in first with `skopeo login ghcr.io`."""
    medium = pathlib.Path(medium)
    medium.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=medium.parent) as work:
        work = pathlib.Path(work)
        oci.pull(ref, work / "files")
        if missing := {MEDIUM_FILE, RECORD_FILE} - {p.name for p in (work / "files").iterdir()}:
            sys.exit(f"error: {ref} has no {', '.join(sorted(missing))}")
        with lzma.open(work / "files" / MEDIUM_FILE) as source, open(medium, "wb") as out:
            shutil.copyfileobj(source, out, 1024 * 1024)
        record = json.loads((work / "files" / RECORD_FILE).read_text())
    if archive.sha256(medium) != record["medium_sha256"]:
        sys.exit(f"error: {medium} differs from its record")
    medium.with_name(medium.name + ".json").write_text(json.dumps(record, indent=2) + "\n")
    log(f"Pulled installer {record['version']} from {ref}")
