"""desktop/assistant/actions.py and skills.py: arguments are checked against
each action's schema, apps are found by the names people use, and skills are
read from their files: the OS's as they are, and the person's, which can be
added, changed, and deleted."""

import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parents[2] / "desktop" / "assistant"))
import actions  # noqa: E402
import skills  # noqa: E402


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


def test_every_action_has_a_risk_and_changes_and_looks_have_a_group():
    for action in actions.ACTIONS.values():
        assert action.risk in ("read", "see", "change", "confirm")
        assert (action.group in actions.GROUPS) == (action.risk in ("change", "see")), action.name
    assert {a.name for a in actions.ACTIONS.values() if a.group == "screen"} == {"get_windows", "look_at_screen"}
    # What brings text from elsewhere into the request.
    assert {a.name for a in actions.ACTIONS.values() if a.group == "web"} == {"read_web_page", "search_wikipedia"}
    assert {a.name for a in actions.ACTIONS.values() if a.untrusted} == {
        "search_files", "get_windows", "look_at_screen", "read_web_page", "search_wikipedia"}
    # What sends what it is given out.
    assert {a.name for a in actions.ACTIONS.values() if a.outward} == {"read_web_page", "search_wikipedia"}
    assert {a.name for a in actions.ACTIONS.values() if a.risk == "confirm"} == {"power_off", "restart", "install_app", "remove_app"}


def skill(directory, name, body):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / f"{name}.md").write_text(body)


@pytest.fixture
def skill_dirs(tmp_path, monkeypatch):
    monkeypatch.setattr(skills, "VENDOR", tmp_path / "vendor")
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "config"))
    skill(tmp_path / "vendor", "writing", "---\nname: writing\ndescription: Write.\ntemperature: 0.8\n---\nWrite well.\n")
    return tmp_path / "config" / "assistant" / "skills"


def test_skills_are_read_and_the_oses_stay_as_they_are(skill_dirs):
    skill(skill_dirs, "mine", "---\nname: writing\ndescription: My way.\n---\nShort.\n")
    skill(skill_dirs, "plain", "---\nname: plain\ndescription: Plain.\n---\nBe plain.\n")
    found = skills.load()
    assert {k: v for k, v in found["writing"].items() if k != "path"} == {
        "name": "writing", "description": "Write.", "temperature": 0.8, "instructions": "Write well.", "own": False}
    assert found["plain"]["instructions"] == "Be plain." and found["plain"]["own"] is True


def test_a_persons_skill_is_added_changed_renamed_and_deleted(skill_dirs):
    skills.save("Notes", " Sum up\n notes. ", 0.5, "List the decisions.")
    assert (skill_dirs / "notes.md").read_text() == "---\nname: notes\ndescription: Sum up notes.\ntemperature: 0.5\n---\nList the decisions.\n"
    skills.save("notes", "Sum up notes.", None, "List the tasks.", previous="notes")
    assert skills.load()["notes"]["instructions"] == "List the tasks." and skills.load()["notes"]["temperature"] is None
    skills.save("meeting-notes", "Sum up notes.", None, "List the tasks.", previous="notes")
    assert sorted(p.name for p in skill_dirs.iterdir()) == ["meeting-notes.md"]
    skills.delete("meeting-notes")
    assert list(skill_dirs.iterdir()) == []


def test_a_skill_that_cant_be_saved_says_why(skill_dirs):
    for args, why in ((("writing", "x", None, "x"), "skill of the system's"), (("Bad name", "x", None, "x"), "small letters"),
                      (("a", "", None, "x"), "needs a description"), (("a", "x", 3, "x"), "from 0 to 2"),
                      (("a", "x", "hot", "x"), "is a number")):  # fmt: skip
        with pytest.raises(ValueError, match=why):
            skills.save(*args)
    skills.save("a", "x", None, "x")
    with pytest.raises(ValueError, match="already"):
        skills.save("a", "y", None, "y")
    with pytest.raises(ValueError, match="no skill called writing"):
        skills.delete("writing")


def test_a_skill_with_a_wrong_header_is_left_out():
    for wrong in ("no header", "---\nname: Bad Name\ndescription: x\n---\nx", "---\nname: a\n---\nno description",
                  "---\nname: a\ndescription: x\ntemperature: hot\n---\nx", "---\nname: a\ndescription: x\ntemperature: 3\n---\nx",
                  "---\nname: a\ndescription: x\n---\n"):  # fmt: skip
        assert skills.parse(wrong) is None, wrong


def test_the_oses_skills_are_well_formed():
    shipped = sorted(skills.VENDOR.glob("*.md"))
    assert shipped
    for path in shipped:
        assert skills.parse(path.read_text()) is not None, path
        assert skills.parse(path.read_text())["name"] == path.stem
