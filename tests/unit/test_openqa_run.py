"""tests/openqa/run.py, on made-up runs."""

import importlib.util
import json
import pathlib

spec = importlib.util.spec_from_file_location("run", pathlib.Path(__file__).parents[1] / "openqa" / "run.py")
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


def run_vars(tmp_path):
    record = tmp_path / "installer.raw.json"
    record.write_text(json.dumps({"image_digest": "sha256:abc"}))
    key = tmp_path / "id.pub"
    key.write_bytes(b"ssh-ed25519 AAAA")
    return run.run_vars(record, key, "dev", "14G", "20G")


def test_vars_add_the_runs_values_to_the_fixed_ones(tmp_path):
    values = run_vars(tmp_path)
    assert values["DISTRI"] == "shapebit"
    assert values["HDDSIZEGB_1"] == 14
    assert values["HDDSIZEGB_2"] == 20
    assert values["OWNER_NAME"] == "dev"
    assert values["IMAGE_DIGEST"] == "sha256:abc"
    assert values["QEMU_APPEND"].endswith("ssh.authorized_keys.root=c3NoLWVkMjU1MTkgQUFBQQ==")


def test_owner_password_can_be_typed_and_is_new_for_each_run(tmp_path):
    first, second = run_vars(tmp_path)["OWNER_PASSWORD"], run_vars(tmp_path)["OWNER_PASSWORD"]
    assert first.isalnum() and first.isascii()
    assert first != second


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
