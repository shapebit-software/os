# ShapeBit Agents

Private, shared agent workflows for ShapeBit repositories.

## Layout

```text
skills/
└── <skill-name>/
    ├── SKILL.md
    ├── references/  # optional
    ├── scripts/     # optional
    └── assets/      # optional
```

Each consuming repository adds this repository as the `.agents/shared`
submodule. It exposes selected shared skills and any repository-local skills
through `.agents/skills` for Codex and `.claude/skills` for Claude Code.

## Compatibility

Shared skills use the portable Agent Skills subset:

- `name` and `description` frontmatter
- Markdown instructions
- relative references, scripts, and assets

Tool-specific settings, hooks, permissions, and subagent definitions remain in
the consuming repository.

## Install in a ShapeBit repository

The repository is private, so authenticate GitHub CLI first. Download the
management command to a temporary path, inspect it, and run `init` from the
repository that should consume the shared skills:

```bash
gh auth status
gh api repos/shapebit-software/agents/contents/bin/shapebit-agents \
  --jq .content | base64 --decode > /tmp/shapebit-agents
chmod +x /tmp/shapebit-agents
less /tmp/shapebit-agents
/tmp/shapebit-agents init
```

`init` creates this structure:

```text
.agents/
├── shared/       # this repository as a Git submodule
└── skills/       # selected shared skills and repository-local skills
.claude/
└── skills        # symlink to ../.agents/skills
CLAUDE.md         # imports AGENTS.md
```

If an agent session mounts `.agents` as read-only, run `init` from a normal
terminal before opening that repository in the agent.

## Manage skills

After initialization, use the command from the pinned shared repository:

```bash
.agents/shared/bin/shapebit-agents list
.agents/shared/bin/shapebit-agents add <skill-name>
.agents/shared/bin/shapebit-agents remove <skill-name>
.agents/shared/bin/shapebit-agents update
```

`list` reports each shared skill as `enabled`, `disabled`, `local`, or
`conflict`. `add` creates a relative symlink under `.agents/skills`. `remove`
deletes only symlinks managed by this command and refuses to remove local
skills or unrelated links.

The consuming repository pins the shared submodule revision. After `update`,
review and commit the changed `.agents/shared` pointer.
