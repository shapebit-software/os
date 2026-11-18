"""Download and stage a newer build, restart into it, and roll back to the
build before. Runs after check_to_next.py, on the next build."""

import json


def test_os_update_downloads_and_stages_a_newer_build(setting, publish, check_for_update):
    publish("next2")
    assert check_for_update() == f"ready {setting('NEXT2_VERSION')}"


def test_restarting_boots_the_downloaded_build(machine, setting, running):
    machine.reboot()
    assert running() == setting("NEXT2_VERSION")


def test_rollback_boots_the_previous_build(machine, sh, setting, running):
    assert json.loads(sh("bootc status --format=json"))["status"]["rollback"] is not None
    sh("bootc rollback")
    machine.reboot()
    assert running() == setting("NEXT_VERSION")


def test_machine_state_survives_the_rollback(state_survives):
    state_survives()
