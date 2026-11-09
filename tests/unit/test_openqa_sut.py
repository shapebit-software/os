"""tests/openqa/lib/sut.py, without a machine: SSH is faked."""

import importlib.util
import pathlib
import subprocess

import pytest


@pytest.fixture
def sut(monkeypatch):
    monkeypatch.setenv("OWNER_NAME", "dev")
    path = pathlib.Path(__file__).parents[1] / "openqa" / "lib" / "sut.py"
    spec = importlib.util.spec_from_file_location("sut", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_a_failure_keeps_the_journal_and_core_dumps(sut, monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(sut, "ssh", lambda command: subprocess.CompletedProcess(command, 0, f"out of {command}\n", ""))
    sut.journal_on_failure("login")(None)
    saved = (tmp_path / "journal-login.txt").read_text()
    for command in ("journalctl -b", "coredumpctl list", "coredumpctl info"):
        assert f"out of {command}" in saved


def test_a_machine_out_of_reach_still_leaves_a_file(sut, monkeypatch, tmp_path):
    # Without SSH, as before the installer has booted, ssh's own error is the log.
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(sut, "ssh", lambda command: subprocess.CompletedProcess(command, 255, "", "Connection refused\n"))
    sut.journal_on_failure("install")(None)
    assert "Connection refused" in (tmp_path / "journal-install.txt").read_text()
