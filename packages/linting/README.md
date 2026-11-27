# Linting

How ShapeBit's code is checked without running it: `make lint`, and the tools
that `make validate` runs. shapebit-linting installs them, so that a package
outside this repository is checked the same way. No OS image has it.

| File | What it is |
| --- | --- |
| `src/lint.sh` | Checks every shell file (`bash -n`), Python file (pyflakes), and Rust file (rustfmt) in the folders given, by extension or first line. |
| `data/rustfmt.toml` | Rust's formatting rules. |

The spec's Requires are the tools: also qmllint, which a feature's own `lint`
target runs (the shell's), reuse, for every file's license, and
license-validate, for each spec's License. Checks of this repository as a
whole, such as what the specs require from Fedora (`image/requires.sh
--check`), stay with what they check.
