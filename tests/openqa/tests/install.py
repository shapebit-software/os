"""Install through the medium's UI, as a person does."""

import sys

from testapi import *

sys.path.insert(0, get_var("CASEDIR") + "/lib")
import sut

OWNER = get_var("OWNER_NAME")
PASSWORD = get_var("OWNER_PASSWORD")


def page(name, timeout=30):
    """Each page's picture stays in the results; only the first and the erasing
    are compared, as what they show is what those steps test."""
    sut.wait_for_page(name, timeout)
    save_screenshot()


def run(self):
    assert_screen("installer-welcome", 300)
    sut.wait_for_ssh()
    page("welcome")
    # The screen says that it is the installer; the system agrees.
    assert sut.run("systemctl is-active installer.service").strip() == "active"
    assert sut.run("systemctl is-enabled sddm.service", check=False).strip() == "masked"
    disks = sut.run("installerctl disks")
    assert '"id":"serial-target"' in disks

    send_key("ret")
    page("keyboard")
    send_key("ret")
    page("network")
    send_key("ret")
    page("timezone")
    send_key("ret")
    page("account")
    # First name (from which the UI derives the user name), last name, password.
    type_string(OWNER)
    send_key("tab")
    send_key("tab")
    type_password(PASSWORD)
    send_key("tab")
    type_password(PASSWORD)
    wait_still_screen(2)
    save_screenshot()
    send_key("ret")
    page("disk")
    # Tab reaches the first eligible disk, Space chooses it, and the next pair
    # confirms. Only the button starts the erasing: Enter does nothing here.
    send_key("tab")
    send_key("spc")
    send_key("tab")
    send_key("spc")
    assert_and_click("installer-erase")
    page("progress", 60)
    page("recovery-key", 1800)
    # The key goes nowhere: it is random, and this machine is thrown away. The
    # finish button stays off until the box is ticked.
    send_key("tab")
    send_key("spc")
    send_key("ret")
    page("done", 60)
    # Installed on the target, not on the medium.
    assert "shapebit" in sut.run("lsblk -no PARTLABEL /dev/disk/by-id/virtio-target")
    sut.remove_medium(perl.autotest.query_isotovideo)
    send_key("ret")


def test_flags(self):
    return {"fatal": 1}
