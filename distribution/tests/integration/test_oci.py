"""distribution/oci.py: the ORAS commands for artifacts of files."""

import importlib.util
import pathlib

import pytest

spec = importlib.util.spec_from_file_location("oci", pathlib.Path(__file__).parents[2] / "oci.py")
oci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oci)


def test_push_names_the_files_from_their_directory_with_the_login(tmp_path, monkeypatch):
    auth = tmp_path / "auth.json"
    auth.write_text("{}")
    monkeypatch.setenv("ENGINE", "sudo podman")
    monkeypatch.setenv("REGISTRY_AUTH_FILE", str(auth))
    calls = []
    monkeypatch.setattr(oci.subprocess, "run", lambda command, check: calls.append(command))
    (tmp_path / "files").mkdir()
    for name in ("b.rpm", "a.rpm"):
        (tmp_path / "files" / name).write_bytes(b"x")
    oci.push("registry/repo:1-sources", "application/vnd.test", "Test 1",
             [tmp_path / "files/b.rpm", tmp_path / "files/a.rpm"])
    command = calls[0]
    assert command[:3] == ["sudo", "podman", "run"]
    assert f"{tmp_path / 'files'}:/work:z" in command and f"{auth}:/auth.json:ro,z" in command
    assert command[command.index(oci.ORAS_IMAGE) + 1:] == [
        "push", "registry/repo:1-sources", "--artifact-type", "application/vnd.test",
        "--annotation", "org.opencontainers.image.title=Test 1", "a.rpm", "b.rpm",
        "--registry-config", "/auth.json"]


@pytest.mark.parametrize("failures, pulled", [(2, True), (3, False)])
def test_a_failed_pull_is_tried_again_up_to_three_times(tmp_path, monkeypatch, failures, pulled):
    monkeypatch.setenv("ENGINE", "podman")
    calls = []

    def run(command, check):
        calls.append(command)
        if len(calls) <= failures:
            raise oci.subprocess.CalledProcessError(1, command)

    monkeypatch.setattr(oci.subprocess, "run", run)
    if pulled:
        oci.pull("registry/repo:1", tmp_path)
    else:
        with pytest.raises(oci.subprocess.CalledProcessError):
            oci.pull("registry/repo:1", tmp_path)
    assert len(calls) == min(failures + 1, 3)


def test_files_from_two_directories_are_refused(tmp_path):
    with pytest.raises(ValueError):
        oci.push("registry/repo:1", "t", "T", [tmp_path / "x/a", tmp_path / "y/b"])
