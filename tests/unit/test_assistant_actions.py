"""desktop/assistant/actions.py: arguments are checked against each action's
schema, and apps are found by the names people use."""

import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parents[2] / "desktop" / "assistant"))
import actions  # noqa: E402


def entry(directory, name, app_id, extra=""):
    (directory / f"{app_id}.desktop").write_text(f"[Desktop Entry]\nType=Application\nName={name}\n{extra}\n[Desktop Action new]\nName=New Window\n")


@pytest.fixture
def apps(tmp_path, monkeypatch):
    directory = tmp_path / "share" / "applications"
    directory.mkdir(parents=True)
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "share"))
    monkeypatch.setenv("XDG_DATA_DIRS", str(tmp_path / "none"))
    entry(directory, "Firefox", "org.mozilla.firefox", "Keywords=web;browser;")
    entry(directory, "Files", "org.gnome.Nautilus", "GenericName=File Manager")
    entry(directory, "Text Editor", "org.gnome.TextEditor")
    entry(directory, "Fonts", "org.gnome.font-viewer")
    entry(directory, "Hidden", "hidden", "NoDisplay=true")
    return directory


def test_an_app_is_found_by_its_name_or_its_words(apps):
    assert actions.find_app("firefox") == ("org.mozilla.firefox.desktop", "Firefox")
    assert actions.find_app("Files") == ("org.gnome.Nautilus.desktop", "Files")
    assert actions.find_app("browser") == ("org.mozilla.firefox.desktop", "Firefox")
    assert actions.find_app("text") == ("org.gnome.TextEditor.desktop", "Text Editor")


def test_an_unclear_or_unknown_name_tells_the_choices(apps):
    with pytest.raises(actions.Failed, match="More than one app matches f: .*Files"):
        actions.find_app("f")
    with pytest.raises(actions.Failed, match="Installed apps: Files, Firefox, Fonts, Text Editor"):
        actions.find_app("spreadsheet")


def test_arguments_are_checked_and_mended_where_plain():
    brightness = actions.ACTIONS["set_brightness"]
    assert brightness.check({"percent": "40"}) == {"percent": 40}
    assert brightness.check({"percent": 40.0}) == {"percent": 40}
    for wrong in ({}, {"percent": 101}, {"percent": True}, {"percent": "much"}):
        with pytest.raises(actions.Failed):
            brightness.check(wrong)
    mute = actions.ACTIONS["set_mute"]
    assert mute.check({"device": "speaker", "muted": "true"}) == {"device": "speaker", "muted": True}
    with pytest.raises(actions.Failed, match="one of speaker, microphone"):
        mute.check({"device": "headphones", "muted": True})


def test_every_action_has_a_risk_and_changes_have_a_group():
    for action in actions.ACTIONS.values():
        assert action.risk in ("read", "change", "confirm")
        assert (action.group in actions.GROUPS) == (action.risk == "change"), action.name
    assert {a.name for a in actions.ACTIONS.values() if a.risk == "confirm"} == {"power_off", "restart", "install_app", "remove_app"}
