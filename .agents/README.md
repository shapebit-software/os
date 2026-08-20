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

