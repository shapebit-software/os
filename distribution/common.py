"""What every step of distribution shares (README.md): the packages on GHCR,
the trust files that computers check updates with, running commands, copying
images and artifacts with skopeo, and GitHub's releases. ENGINE runs
containers of images."""

import contextlib
import json
import os
import pathlib
import shlex
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
# The build's own description of an image archive (image/archive.py): the
# build comes before distribution, so distribution may read it, not the reverse.
for path in (HERE, HERE / "sources", HERE / "sbom", ROOT / "image"):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))
import oci  # noqa: E402
import sources  # noqa: E402

# The packages on GHCR (README.md#versions-and-channels).
REPOSITORY = "ghcr.io/shapebit-software/os"
CANDIDATES = f"{REPOSITORY}/candidate"
INSTALLERS = f"{REPOSITORY}/installer"
VERSION_LABEL = "org.opencontainers.image.version"
REVISION_LABEL = "org.opencontainers.image.revision"
WITHDRAWN = " (withdrawn)"
# What computers check updates with (packages/updates), as the candidate ships
# it: the policy, the release image key's public half, whose private half signs
# at promotion, and where signatures are. The draft keeps their contents, read
# from the candidate, so that promotion checks with what the tested image trusts.
INSTALLED_KEY = "/usr/share/pki/containers/shapebit-os.pub"
TRUST = {"policy": "/etc/containers/policy.json", "key": INSTALLED_KEY,
         "registries": "/usr/share/containers/registries.d/shapebit-os.yaml"}  # fmt: skip


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def run(*args, capture=False, check=True):
    """A command; its output when CAPTURE."""
    done = subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE if capture else sys.stderr)
    return done.stdout if capture else done


def engine():
    return shlex.split(os.environ["ENGINE"])


@contextlib.contextmanager
def stdout_to_stderr():
    """Everything that this process and its commands print goes to stderr, so
    that stdout carries only what a workflow reads, such as GITHUB_OUTPUT's lines."""
    sys.stdout.flush()
    saved = os.dup(1)
    os.dup2(2, 1)
    try:
        with contextlib.redirect_stdout(sys.stderr):
            yield
    finally:
        sys.stdout.flush()
        os.dup2(saved, 1)
        os.close(saved)


def copy(source, destination, *options):
    """An image or artifact, byte for byte, so its digest stays."""
    run("skopeo", "copy", "-q", "--preserve-digests", *options, source, destination)


def exists(ref):
    return oci.registry_digest(ref) is not None


def image_label(ref, key):
    value = run("skopeo", "inspect", "--format", f'{{{{index .Labels "{key}"}}}}', f"docker://{ref}",
                capture=True).strip()
    return "" if value == "<no value>" else value


def os_releases(items):
    """The OS's releases among ITEMS, GitHub's releases: those tagged with a
    version, all digits (README.md#versions-and-channels). The external
    packages' releases, rpm-NAME-VERSION-RELEASE, live in the same list, and
    GitHub may mark one Latest while no OS release is."""
    return [item for item in items if item["tagName"].isdigit()]


def releases():
    return os_releases(json.loads(run("gh", "release", "list", "--limit", "1000", "--json",
                                      "tagName,name,isDraft,isLatest", capture=True)))


def release_record(version):
    with tempfile.TemporaryDirectory() as work:
        run("gh", "release", "download", version, "--pattern", "record.json", "--dir", work)
        return json.loads((pathlib.Path(work) / "record.json").read_text())


def push_sources(directory, ref, title):
    files = sorted(pathlib.Path(directory).glob("*.src.rpm"))
    if not files:
        sys.exit(f"error: no source RPMs in {directory}")
    oci.push(ref, sources.TYPE, title, files)
