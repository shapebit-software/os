"""Update the installed system to the next build, and restart into it. make
test-system-update then runs the installed system's tests on it, then
test_rollback.py."""

import pytest

pytestmark = pytest.mark.system_update(when="before")


def test_os_update_reports_the_staged_build(sh, setting, state, publish, running, check_for_update):
    # The machine follows the local registry, which serves plain HTTP. bootc
    # switches only to an image other than the one running, so the new build
    # goes first.
    original = running()
    for path in state:
        sh(f"echo {original} >{path}")
    publish("next")
    ref = setting("DEV_UPDATE_REF")
    sh(f"printf '[[registry]]\\nlocation = \"%s\"\\ninsecure = true\\n' {ref.split('/', 1)[0]} "
       ">/etc/containers/registries.conf.d/50-dev-registry.conf")
    sh("bootc switch --quiet %s", ref)
    assert check_for_update() == f"ready {setting('NEXT_VERSION')}"
    assert running() == original, "os-update must not restart the system"


def test_restarting_boots_the_new_build(machine, setting, running):
    machine.reboot()
    assert running() == setting("NEXT_VERSION")


def test_os_update_finds_nothing_for_the_running_build(check_for_update):
    assert check_for_update() == "current "


def test_machine_state_survives_the_update(state_survives):
    state_survives()
