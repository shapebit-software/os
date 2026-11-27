"""distribution/release.py: the command line, without registries or GitHub."""

import pytest

import release


def test_the_command_line_refuses_wrong_arguments(monkeypatch):
    called = []
    monkeypatch.setitem(release.COMMANDS, "prune", (0, "--dry-run", lambda *args: called.append(args)))
    release.main("prune")
    release.main("prune", "--dry-run")
    assert called == [(), (True,)]
    for args in [("prune", "--force"), ("digest", "a"), ("nothing",), ()]:
        with pytest.raises(SystemExit):
            release.main(*args)
