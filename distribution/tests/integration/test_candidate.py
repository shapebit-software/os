"""distribution/candidate.py: a candidate's record, and its notes, on made-up
packages and package versions."""

import json
import subprocess

import candidate

DIGEST = "sha256:aaa"
# A candidate's trust files, as the draft keeps them.
TRUST = {
    "policy": json.dumps({"default": [{"type": "insecureAcceptAnything"}], "transports": {"docker": {
        "ghcr.io/shapebit-software/os": [{"type": "sigstoreSigned", "keyPath": "/usr/share/pki/containers/shapebit-os.pub",
                                          "signedIdentity": {"type": "matchRepository"}}]}}}),
    "key": "-----BEGIN PUBLIC KEY-----\nkey\n-----END PUBLIC KEY-----\n",
    "registries": "docker:\n  ghcr.io/shapebit-software/os:\n    use-sigstore-attachments: true\n",
}
SOURCES = "ghcr.io/shapebit-software/os:1-sources"


def changes(old, new):
    return candidate.package_changes(candidate.read_packages(old), candidate.read_packages(new))


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
    notes = candidate.notes(DIGEST, SOURCES, "abc123", "abc123 Fix a thing\n", "a 1-1\n", "a 1-2\n")
    assert notes.startswith("- Image digest: `sha256:aaa`\n- Sources: `ghcr.io/shapebit-software/os:1-sources`\n")
    assert "- Commit: `abc123`\n" in notes
    assert "```\nabc123 Fix a thing\n```" in notes
    assert "- Updated `a` 1-1 → 1-2" in notes


def test_notes_say_when_nothing_changed():
    notes = candidate.notes(DIGEST, SOURCES, "abc123", "", "a 1-1\n", "a 1-1\n")
    assert "```\nNone\n```" in notes
    assert notes.endswith("## Packages changed since stable\nNone\n")


def test_notes_of_a_bootstrap_say_that_no_update_tested_it():
    notes = candidate.notes(DIGEST, SOURCES, "abc123", "", "", "a 1-1\n", bootstrap=True)
    assert notes.startswith("**Bootstrap:** not tested by an update")


def test_a_candidate_is_recorded_by_digest():
    record = candidate.candidate_record("202611180300", "abc123", "sha256:img", "sha256:src", None, TRUST)
    assert record == {
        "version": "202611180300",
        "revision": "abc123",
        "image": "ghcr.io/shapebit-software/os/candidate@sha256:img",
        "sources": "ghcr.io/shapebit-software/os/candidate@sha256:src",
        "sbom": None,
        "trust": TRUST,
    }


def git_history(path, *messages):
    """A repository at PATH with a commit for each of MESSAGES; their hashes."""
    def git(*args):
        return subprocess.run(["git", "-C", str(path), *args], check=True, capture_output=True, text=True).stdout
    git("init", "-q")
    for message in messages:
        git("-c", "user.name=t", "-c", "user.email=t@example.org", "commit", "-q", "--allow-empty", "-m", message)
    return git("log", "--format=%H", "--reverse").split()


def test_notes_list_the_commits_since_stables(tmp_path, monkeypatch):
    first, _ = git_history(tmp_path, "first", "second")
    monkeypatch.chdir(tmp_path)
    assert [line.split()[1] for line in candidate.commits_since(first).splitlines()] == ["second"]


def test_notes_list_every_commit_when_stables_is_gone_or_unknown(tmp_path, monkeypatch):
    # The history started again on 2026-11-23; the stable image names a commit
    # from before.
    git_history(tmp_path, "first", "second")
    monkeypatch.chdir(tmp_path)
    for revision in ("48ba8d02356b70b42012ed8bec1294b72b331a8d", None):
        assert len(candidate.commits_since(revision).splitlines()) == 2
