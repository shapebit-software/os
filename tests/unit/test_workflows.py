"""GitHub workflows and actions pin third-party actions to a commit SHA (.github/dependabot.yml)."""

import pathlib
import re

GITHUB = pathlib.Path(__file__).parents[2] / ".github"
USES = re.compile(r"^\s*(?:-\s*)?uses:\s*(\S+)(.*)$")
PINNED = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")


def test_third_party_actions_are_pinned_to_a_commit():
    files = [*GITHUB.glob("workflows/*.yml"), *GITHUB.glob("actions/*/action.yml")]
    assert files
    unpinned = []
    for path in files:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            match = USES.match(line)
            if not match or match[1].startswith("./"):
                continue
            # The tag comment is what Dependabot updates and what people read.
            if not PINNED.match(match[1]) or not re.match(r"\s+# v\d", match[2]):
                unpinned.append(f"{path.relative_to(GITHUB)}:{number}: {line.strip()}")
    assert not unpinned, "pin to a full commit SHA with '# vX.Y.Z':\n" + "\n".join(unpinned)
