"""The update test (README.md). Two builds go to the local registry under
their own tags: next (--next), newer than the installed one (in Candidate,
the candidate, and the installed one is stable), and next2 (--next2), newer
still. Moving the tag that the system follows (DEV_UPDATE_REF's) to one of
them is what publishing a build does."""

import urllib.request

import pytest

# Machine state, which an update and a rollback keep.
STATE = ["/etc/update-check", "/var/lib/update-check"]
ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])  # fmt: skip


@pytest.fixture(scope="session")
def publish(request, setting, serve_build):
    """Move the tag that the system follows to next or next2, which go to the
    registry first. The registry runs on this host; the machine reaches it at
    DEV_UPDATE_REF."""
    for option, tag in (("--next", "next"), ("--next2", "next2")):
        serve_build(request.config.getoption(option), tag)

    def run(tag):
        name, followed = setting("DEV_UPDATE_REF").split("/", 1)[1].rsplit(":", 1)
        base = f"http://127.0.0.1:{setting('REGISTRY_PORT')}/v2/{name}/manifests"
        request = urllib.request.Request(f"{base}/{tag}", headers={"Accept": ACCEPT})
        with urllib.request.urlopen(request) as response:
            manifest, kind = response.read(), response.headers["Content-Type"]
        request = urllib.request.Request(f"{base}/{followed}", data=manifest, method="PUT",
                                         headers={"Content-Type": kind})
        urllib.request.urlopen(request).close()

    return run


@pytest.fixture(scope="session")
def running(host):
    """The version of the build that runs."""

    def read():
        lines = host.file("/etc/os-release").content_string.splitlines()
        return dict(line.split("=", 1) for line in lines if "=" in line)["IMAGE_VERSION"].strip('"')

    return read


@pytest.fixture(scope="session")
def check_for_update(sh):
    """What os-update finds, as "STATE VERSION"."""

    def run():
        sh("systemctl start os-update@now.service")
        return sh("""jq -r '.state + " " + .version' /run/os-update/status.json""").rstrip("\n")

    return run


@pytest.fixture(scope="session")
def state():
    return STATE


@pytest.fixture(scope="session")
def state_survives(host):
    def check():
        for path in STATE:
            assert host.file(path).exists, path

    return check
