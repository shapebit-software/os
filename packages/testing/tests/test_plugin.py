"""The plugin's reading of a test's level from its markers."""

import pytest

from testing.plugin import level


def test_a_test_with_no_levels_marker_is_a_unit_test():
    assert level(set()) == "unit"
    assert level({"parametrize", "skipif"}) == "unit"


def test_the_markers_say_the_other_levels():
    assert level({"integration"}) == "integration"
    assert level({"system_image"}) == "system"
    assert level({"system_update", "parametrize"}) == "system"


def test_a_test_has_one_level():
    with pytest.raises(ValueError, match="two levels"):
        level({"integration", "system_installed"})
    with pytest.raises(ValueError, match="two levels"):
        level({"system_image", "system_installed"})
