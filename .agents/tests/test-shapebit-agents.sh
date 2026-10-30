#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TOOL="$PROJECT_ROOT/bin/shapebit-agents"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/shapebit-agents-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

shared="$test_root/shared"
consumer="$test_root/consumer"

git init --initial-branch=main "$shared" >/dev/null
git -C "$shared" config user.name "ShapeBit Test"
git -C "$shared" config user.email "test@shapebit.software"
mkdir -p "$shared/skills/alpha" "$shared/skills/beta"
printf '%s\n' '---' 'name: alpha' 'description: Alpha test skill.' '---' >"$shared/skills/alpha/SKILL.md"
printf '%s\n' '---' 'name: beta' 'description: Beta test skill.' '---' >"$shared/skills/beta/SKILL.md"
git -C "$shared" add skills
git -C "$shared" commit -m "test: add shared skills" >/dev/null

git init --initial-branch=main "$consumer" >/dev/null
git -C "$consumer" config user.name "ShapeBit Test"
git -C "$consumer" config user.email "test@shapebit.software"
printf '# Test repository\n' >"$consumer/AGENTS.md"
git -C "$consumer" add AGENTS.md
git -C "$consumer" commit -m "test: initialize consumer" >/dev/null

run_tool() {
    (
        cd "$consumer"
        GIT_ALLOW_PROTOCOL=file SHAPEBIT_AGENTS_URL="$shared" "$TOOL" "$@"
    )
}

run_tool init >/dev/null
[ -f "$consumer/.agents/skills/.gitkeep" ]
[ "$(readlink "$consumer/.claude/skills")" = '../.agents/skills' ]
grep -Fxq '@AGENTS.md' "$consumer/CLAUDE.md"

list_output="$(run_tool list)"
grep -Eq '^alpha[[:space:]]+disabled$' <<<"$list_output"
grep -Eq '^beta[[:space:]]+disabled$' <<<"$list_output"

if run_tool add alpha missing >/dev/null 2>&1; then
    printf 'add unexpectedly accepted an unavailable skill\n' >&2
    exit 1
fi
[ ! -e "$consumer/.agents/skills/alpha" ]

run_tool add alpha >/dev/null
[ "$(readlink "$consumer/.agents/skills/alpha")" = '../shared/skills/alpha' ]
grep -Eq '^alpha[[:space:]]+enabled$' <<<"$(run_tool list)"
run_tool add alpha >/dev/null

mkdir -p "$consumer/.agents/skills/beta"
if run_tool remove beta >/dev/null 2>&1; then
    printf 'remove unexpectedly deleted a repository-local skill\n' >&2
    exit 1
fi
[ -d "$consumer/.agents/skills/beta" ]

run_tool remove alpha >/dev/null
[ ! -e "$consumer/.agents/skills/alpha" ]
run_tool remove alpha >/dev/null
run_tool init >/dev/null

mkdir -p "$shared/skills/gamma"
printf '%s\n' '---' 'name: gamma' 'description: Gamma test skill.' '---' >"$shared/skills/gamma/SKILL.md"
git -C "$shared" add skills/gamma/SKILL.md
git -C "$shared" commit -m "test: add another skill" >/dev/null
run_tool update >/dev/null
grep -Eq '^gamma[[:space:]]+disabled$' <<<"$(run_tool list)"

printf 'All shapebit-agents tests passed.\n'
