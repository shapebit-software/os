"""development/sync.py, without a machine."""

import importlib.util
import io
import pathlib
import tarfile

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("sync", ROOT / "development/sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


def test_the_archive_holds_only_each_features_usr_owned_by_root(tmp_path):
    (tmp_path / "shell/usr/share/desktop").mkdir(parents=True)
    (tmp_path / "shell/usr/share/desktop/a.qml").write_text("Item {}")
    (tmp_path / "release/etc").mkdir(parents=True)
    (tmp_path / "release/etc/os-release").write_text("ID=shapebit")
    (tmp_path / "release/usr/lib").mkdir(parents=True)
    (tmp_path / "release/usr/lib/os-release").write_text("ID=shapebit")

    with tarfile.open(fileobj=io.BytesIO(sync.archive(tmp_path))) as tar:
        members = tar.getmembers()

    files = {member.name for member in members if member.isfile()}
    assert files == {"release/usr/lib/os-release", "shell/usr/share/desktop/a.qml", "release/requires", "shell/requires"}
    assert {(member.uid, member.gid, member.uname) for member in members} == {(0, 0, "root")}


def test_the_archive_lists_what_each_feature_requires(tmp_path):
    # So that sync-apply.sh also refreshes the shell when Colors changes.
    (tmp_path / "shell/usr/share").mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(sync.archive(tmp_path))) as tar:
        assert tar.extractfile("shell/requires").read() == b"colors\n"


def test_a_feature_requires_what_its_spec_requires():
    assert sync.requires("shell") == ["colors"]
    assert "shell" in sync.requires("system")
    assert sync.requires("colors") == []


def test_the_vm_is_reached_over_ssh_as_root(monkeypatch, tmp_path):
    monkeypatch.setenv("BUILD", str(tmp_path))
    monkeypatch.setenv("MACHINE", "vm")
    argv = sync.command("echo hi")
    assert argv[0] == "ssh" and "root@127.0.0.1" in argv
    assert argv[-1] == "bash -c 'echo hi'"


def test_this_computer_is_reached_through_the_engine_in_its_namespaces(monkeypatch):
    monkeypatch.setenv("MACHINE", "local")
    monkeypatch.setenv("ENGINE", "podman")
    monkeypatch.setenv("DEV_IMAGE", "localhost/shapebit-dev")
    argv = sync.command("echo hi")
    assert argv[:2] == ["podman", "run"] and "--pid=host" in argv
    assert argv[-7:] == ["nsenter", "--target", "1", "--all", "bash", "-c", "echo hi"]


def test_the_simulator_is_reached_through_the_engine(monkeypatch):
    monkeypatch.setenv("MACHINE", "simulator")
    monkeypatch.setenv("ENGINE", "sudo podman")
    argv = sync.command("echo hi")
    assert argv == ["sudo", "podman", "exec", "-i", sync.SIMULATOR, "bash", "-c", "echo hi"]


def test_another_machine_is_refused(monkeypatch):
    monkeypatch.setenv("MACHINE", "laptop")
    with pytest.raises(SystemExit):
        sync.command("echo hi")
