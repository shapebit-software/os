"""The plugin's reading of a test's level from its folder."""

import pathlib

from testing.plugin import level


def test_the_level_is_the_folder_after_tests():
    assert level(pathlib.Path("packages/network/tests/unit/test_wifi.py")) == "unit"
    assert level(pathlib.Path("packages/network/tests/integration/test_connection_agent.py")) == "integration"
    assert level(pathlib.Path("packages/boot/tests/system/test_boot.py")) == "system"


def test_a_data_folder_inside_a_level_keeps_the_level():
    assert level(pathlib.Path("packages/extras/tests/integration/data/test_fake.py")) == "integration"


def test_a_test_outside_a_level_folder_has_none():
    assert level(pathlib.Path("packages/test_install.py")) is None
    assert level(pathlib.Path("packages/colors/tests/test_colors.py")) is None
    assert level(pathlib.Path("packages/colors/tests/slow/test_colors.py")) is None


def test_the_last_tests_folder_counts():
    assert level(pathlib.Path("packages/testing/tests/unit/data/tests/system/test_x.py")) == "system"
