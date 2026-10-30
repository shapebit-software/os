"""The update stages. The host published both new builds to the local registry
under their own tags; "moving" DEV_UPDATE_REF's tag from here is what publishing
a build does, without the host having to act between the stages."""

import json
import pathlib
import urllib.request

import pytest

STATE = ["/etc/update-check", "/var/lib/update-check"]
ACCEPT = ", ".join(
    [
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.v2+json",
    ]
)


@pytest.fixture
def publish(setting):
    """Move the tag that the system follows to a build that the host published."""

    def run(tag):
        host, repository = setting("DEV_UPDATE_REF").split("/", 1)
        name, followed = repository.rsplit(":", 1)
        base = f"http://{host}/v2/{name}/manifests"
        request = urllib.request.Request(f"{base}/{tag}", headers={"Accept": ACCEPT})
        with urllib.request.urlopen(request) as response:
            manifest = response.read()
            kind = response.headers["Content-Type"]
        request = urllib.request.Request(
            f"{base}/{followed}", data=manifest, method="PUT", headers={"Content-Type": kind}
        )
        urllib.request.urlopen(request).close()

    return run


@pytest.fixture
def running(host):
    def read():
        lines = host.file("/etc/os-release").content_string.splitlines()
        return dict(line.split("=", 1) for line in lines if "=" in line)["IMAGE_VERSION"].strip('"')

    return read


@pytest.fixture
def check_for_update(sh):
    def run():
        sh("systemctl start os-update@now.service")
        return sh("""jq -r '.state + " " + .version' /run/os-update/status.json""").rstrip("\n")

    return run


@pytest.mark.switched
def test_os_update_reports_the_staged_build(sh, setting, publish, running, check_for_update):
    # The VM follows the local registry, which serves plain HTTP. bootc switches
    # only to an image other than the one running, so the new build goes first.
    original = running()
    for path in STATE:
        pathlib.Path(path).write_text(original)
    publish("next")
    ref = setting("DEV_UPDATE_REF")
    registry = ref.split("/", 1)[0]
    pathlib.Path("/etc/containers/registries.conf.d/50-dev-registry.conf").write_text(
        f'[[registry]]\nlocation = "{registry}"\ninsecure = true\n'
    )
    sh("bootc switch --quiet %s", ref)
    assert check_for_update() == f"ready {setting('IMAGE_VERSION')}.next"
    assert running() == original, "os-update must not restart the system"


@pytest.mark.updated
def test_restarting_boots_the_new_build(setting, running):
    assert running() == f"{setting('IMAGE_VERSION')}.next"


@pytest.mark.updated
def test_os_update_finds_nothing_for_the_running_build(check_for_update):
    assert check_for_update() == "current "


@pytest.mark.updated
def test_machine_state_survives_the_update():
    for path in STATE:
        assert pathlib.Path(path).exists(), path


@pytest.mark.downloaded
def test_restarting_boots_the_downloaded_build(setting, running):
    assert running() == f"{setting('IMAGE_VERSION')}.next2"


@pytest.mark.updated
def test_os_update_downloads_and_stages_a_newer_build(setting, publish, check_for_update):
    # Runs last of its stage: pytest keeps the order of the file.
    publish("next2")
    assert check_for_update() == f"ready {setting('IMAGE_VERSION')}.next2"


@pytest.mark.downloaded
def test_rollback_is_accepted(sh):
    assert json.loads(sh("bootc status --format=json"))["status"]["rollback"] is not None
    sh("bootc rollback")


@pytest.mark.rolled_back
def test_rollback_boots_the_previous_build(setting, running):
    assert running() == f"{setting('IMAGE_VERSION')}.next"


@pytest.mark.rolled_back
def test_machine_state_survives_the_rollback():
    for path in STATE:
        assert pathlib.Path(path).exists(), path
