"""tests/openqa/run.py, on made-up runs."""

import importlib.util
import json
import pathlib

import pytest

spec = importlib.util.spec_from_file_location("run", pathlib.Path(__file__).parents[1] / "openqa" / "run.py")
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


def run_vars(tmp_path, *flow):
    record = tmp_path / "installer.img.json"
    record.write_text(json.dumps({"image_digest": "sha256:abc"}))
    key = tmp_path / "id.pub"
    key.write_bytes(b"ssh-ed25519 AAAA")
    return run.run_vars(record, key, "dev", "7G", "20G", *flow)


def test_vars_add_the_runs_values_to_the_fixed_ones(tmp_path):
    values = run_vars(tmp_path)
    assert values["DISTRI"] == "shapebit"
    assert values["HDDSIZEGB_1"] == 7
    assert values["HDDSIZEGB_2"] == 20
    assert values["OWNER_NAME"] == "dev"
    assert values["IMAGE_DIGEST"] == "sha256:abc"
    assert values["QEMU_APPEND"].endswith("ssh.authorized_keys.root=c3NoLWVkMjU1MTkgQUFBQQ==")


def test_install_is_the_flow_by_default(tmp_path):
    values = run_vars(tmp_path)
    assert values["FLOW"] == "install"
    assert "UPDATE_DIGEST" not in values


def test_update_moves_to_the_digest_given(tmp_path):
    values = run_vars(tmp_path, "update", "sha256:new")
    assert values["FLOW"] == "update"
    assert values["UPDATE_DIGEST"] == "sha256:new"
    assert values["IMAGE_DIGEST"] == "sha256:abc"


@pytest.mark.parametrize("flow", [("update", ""), ("install", "sha256:new"), ("upgrade", "")])
def test_a_flow_needs_its_digest_and_only_it(tmp_path, flow):
    with pytest.raises(ValueError):
        run_vars(tmp_path, *flow)


def test_owner_password_can_be_typed_and_is_new_for_each_run(tmp_path):
    first, second = run_vars(tmp_path)["OWNER_PASSWORD"], run_vars(tmp_path)["OWNER_PASSWORD"]
    assert first.isalnum() and first.isascii()
    assert first != second


def needle(directory, name, tag, image):
    directory.mkdir(exist_ok=True)
    (directory / f"{name}.json").write_text(json.dumps({"tags": [tag]}))
    (directory / f"{name}.png").write_bytes(image)


def test_needles_add_an_older_commits_look_under_the_same_tag(tmp_path):
    needle(tmp_path / "tree", "login-screen", "login-screen", b"violet")
    needle(tmp_path / "3794e90", "login-screen", "login-screen", b"plum")
    run.needles(tmp_path / "tree", tmp_path / "out", tmp_path / "3794e90")
    assert sorted(p.name for p in (tmp_path / "out").iterdir()) == [
        "login-screen-3794e90.json", "login-screen-3794e90.png", "login-screen.json", "login-screen.png"]
    assert (tmp_path / "out" / "login-screen-3794e90.png").read_bytes() == b"plum"
    assert json.loads((tmp_path / "out" / "login-screen-3794e90.json").read_text())["tags"] == ["login-screen"]


def test_needles_skip_what_did_not_change_and_keep_what_went(tmp_path):
    needle(tmp_path / "tree", "boot-splash", "boot-splash", b"same")
    needle(tmp_path / "old", "boot-splash", "boot-splash", b"same")
    needle(tmp_path / "old", "installer-welcome", "installer-welcome", b"old")
    run.needles(tmp_path / "tree", tmp_path / "out", tmp_path / "old")
    assert sorted(p.stem for p in (tmp_path / "out").glob("*.png")) == ["boot-splash", "installer-welcome-old"]


def test_needles_without_older_commits_are_the_trees(tmp_path):
    needle(tmp_path / "tree", "boot-splash", "boot-splash", b"same")
    run.needles(tmp_path / "tree", tmp_path / "out")
    assert sorted(p.name for p in (tmp_path / "out").iterdir()) == ["boot-splash.json", "boot-splash.png"]


def results(tmp_path, *outcomes):
    for number, outcome in enumerate(outcomes):
        (tmp_path / f"result-{number}.json").write_text(json.dumps({"result": outcome}))
    return tmp_path


def test_check_passes_when_every_module_passed(tmp_path):
    assert run.passed(results(tmp_path, "ok", "ok"))


def test_check_fails_when_a_module_failed(tmp_path):
    assert not run.passed(results(tmp_path, "ok", "fail"))


def test_check_fails_when_no_module_ran(tmp_path):
    assert not run.passed(tmp_path)
