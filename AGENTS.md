# ShapeBit Agents

## General Guidelines

- Always be as precise and concise as possible, without sacrificing completeness or clarity.
- Keep repository content in English.
- Do not credit AI tools, such as Claude or ChatGPT, in commit messages, pull
  requests, or code comments: no `Co-Authored-By` lines or "Generated with" notes.

## ShapeBit OS

- Product: **ShapeBit OS**; use **ShapeBit** as the short name.
- Monorepo: https://github.com/shapebit-software/os
- GitHub organization: https://github.com/shapebit-software
- Website: https://shapebit.software
- GitHub issues: set the issue type (Bug, Feature, or Task) always.

## Architecture Guidelines

- Dependencies follow the pipeline.
- External packages live in the feature that needs them.
- Verify with unit tests.
- Tests go in `tests/` beside their code; markers say the level: none (unit), `integration`, `system_*`; openQA in `tests/e2e/` (packages/testing/README.md).
- Every package builds and tests on its own: `$(PACKAGING)`, never `../`; tests use `package_dir`/`sibling` (packages/README.md).
- Prefer built-in tools.
- Workflows only call commands.
- A bug becomes a regression test
- Never put credentials in the image or disk.
- Keep shell scripts small.
- Languages: QML for the shell, Rust for services and complex programs, Python for scripts, integration tests, and simple programs; Bash where it is simpler than Python; C and C++ only in legacy code.

## Documentation

- `guidebook/` is for people who use ShapeBit, end-users.
- Developer documentation lives beside its code: README files.
