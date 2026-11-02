"""scripts/release-notes.py, on made-up packages and commits."""

import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location(
    "release_notes", pathlib.Path(__file__).parents[2] / "scripts" / "release-notes.py"
)
release_notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_notes)

RECORD = {"image_digest": "sha256:aaa", "medium_sha256": "bbb"}


def changes(old, new):
    return release_notes.package_changes(release_notes.read_packages(old), release_notes.read_packages(new))


def test_lists_added_removed_and_updated_packages_by_name():
    assert changes("bash 5-1\ngone 1-1\nsame 1-1\n", "bash 5-2\nnew 2-1\nsame 1-1\n") == [
        "- Updated `bash` 5-1 → 5-2",
        "- Removed `gone` 1-1",
        "- Added `new` 2-1",
    ]


def test_a_package_keeps_all_its_versions():
    assert changes("kernel 1-1\nkernel 2-1\n", "kernel 2-1\nkernel 3-1\n") == [
        "- Updated `kernel` 1-1, 2-1 → 2-1, 3-1"
    ]


def test_notes_name_the_build_and_its_changes():
    notes = release_notes.notes(RECORD, "abc123", "abc123 Fix a thing\n", "a 1-1\n", "a 1-2\n")
    assert "- Image digest: `sha256:aaa`\n- Medium SHA-256: `bbb`\n- Commit: `abc123`\n" in notes
    assert "```\nabc123 Fix a thing\n```" in notes
    assert "- Updated `a` 1-1 → 1-2" in notes


def test_notes_say_when_nothing_changed():
    notes = release_notes.notes(RECORD, "abc123", "", "a 1-1\n", "a 1-1\n")
    assert "```\nNone\n```" in notes
    assert notes.endswith("## Packages changed since stable\nNone\n")
