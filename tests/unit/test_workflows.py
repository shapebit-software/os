"""GitHub workflows and actions: third-party actions are pinned to a commit SHA
(.github/dependabot.yml), and the release keys are present only for signing builds."""

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


RESTORE = "uses: ./.github/actions/release-keys"
REMOVE = 'rm -rf "$RUNNER_TEMP/keys"'
SIGNING_BUILD = re.compile(r"make (-o image )?(image|installer|update-builds)( [A-Z_]+=\S+)*")


def test_release_keys_are_on_the_runner_only_for_signing_builds():
    # docs/Design-Security.md: the keys come only through the release-keys
    # action, and between it and their removal only builds that sign run.
    restored = 0
    for path in GITHUB.glob("workflows/*.yml"):
        lines = [line.strip() for line in path.read_text().splitlines()]
        for number, line in enumerate(lines):
            if "secrets.RELEASE_" in line:
                near = lines[max(number - 3, 0):number]
                assert any(n.endswith(RESTORE) for n in near), f"{path.name}:{number + 1}: {line}"
            if not line.endswith(RESTORE):
                continue
            restored += 1
            end = next((n for n in range(number, len(lines)) if lines[n].endswith(REMOVE)), None)
            assert end, f"{path.name}:{number + 1}: the release keys are never removed"
            for step in lines[number + 1:end]:
                assert not step.startswith(("uses:", "- uses:")), f"{path.name}: {step} while keys are present"
                if step.startswith("run:"):
                    assert SIGNING_BUILD.fullmatch(step.removeprefix("run:").strip()), \
                        f"{path.name}: '{step}' runs while the release keys are present"
    assert restored >= 2
