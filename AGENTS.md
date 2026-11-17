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

## Image

These rules cover the image: `packages/`, `distribution/`, `development/` and the
`Makefile`.

- **A folder in `packages/` is a feature and a package.** It holds
  everything about the feature, side by side: its code, its scripts, its
  tests, its `Makefile` with the install rules (CMake for the installer), and
  its spec, named `shapebit-<folder>`, with its `Requires`, each with the
  reason for it. Specs load `packages/package.macros`, Makefiles include
  `packages/package.mk`. Every package carries its license as `%license`:
  ShapeBit's, one shared file, unless it packages others' work (`font`). There are no folders by file type, such as
  `scripts/`, `tests/` or `data/`. `shapebit-system` requires every feature.
- **External packages live in the feature that needs them.** A folder with a
  spec and a `sources` file (Fedora's format) below a feature, such as
  `packages/dictation/sherpa-onnx/`, is software that ShapeBit builds and
  publishes in its own repository (`packages/repositories/README.md`), only
  when its version or `Release` changes; the image installs it from there.
  Patches go beside its spec.
- **Tests are named by where they run.** `test_*.py` (and the installer's
  `tst_*.cpp`, the shell's `tst_*.qml`) are unit tests, which need no machine;
  `check_*.py` check the built OS, in its container or on a VM. Test file
  names are unique across the repository. `packages/test_install.py` fails on
  a file that no install rule installs.

- **Verify with unit tests.** Run `make test-unit` inside `make dev`. A change is
  done only when it passes. Everything else, such as `make static-checks`,
  `make test`, and `make test-release`, is optional, because CI runs it
  ([distribution/README.md](distribution/README.md#testing)); say which of these you did not run. Add
  `ENGINE=docker` on hosts without Podman.
- **Prefer built-in tools.** Use what bootc, systemd, the Fedora base image, or
  QEMU already provide, such as `kargs.d`, systemd credentials, tmpfiles.d,
  sysusers.d, and presets. Add a package, script, or service only when nothing
  built in fits, and say why in a comment.
- **Make owns configuration.** Defaults live only in the `Makefile`. Scripts
  read them from the environment and fail fast on missing values
  (`: "${VAR:?}"`).
- **`distribution/` only assembles.** It builds every package of `packages/` from
  the same commit, reproducibly (`SOURCE_DATE_EPOCH`), checks them with
  rpmlint (`packages/rpmlint.toml`), and installs them with what they require.
  The build fails on a file under `/usr` that no package owns, or that differs
  from its package (`distribution/image/packaged.py`).
- **Vendor defaults go under `/usr`,** by a feature's install rules. `/etc`
  and `/var` are machine state.
- **Every behavior gets a check, beside what it checks.** See
  [distribution/README.md](distribution/README.md#testing). Logic that needs no machine gets a unit
  test next to its code. The built OS is checked in `distribution/`: its content in
  `content/`; the installer medium in `medium/`; the installed, running system
  in `installed/`; updates in `update/`; what a person sees and does in
  `openqa/`. Write checks in Python with pytest and Testinfra. The system
  under test gets nothing installed for a check: use the commands it ships. Only checks that
  need a host-side secret, such as the recovery key, run from the host, in
  `distribution/checks/installed/check_recovery_key.py`.
- **A bug becomes a regression test** at the lowest level that shows it.
- **Disks are installed by the installer.** `make disk` boots the installer
  medium and installs through it, so the tests cover what users run. Do not
  add a second way to produce an installed disk.
- **Never put credentials in the image or disk.** Development access goes
  through systemd credentials at VM launch. Private signing keys reach builds
  only as build secrets; only signed binaries and public keys enter the image.
- **Keep shell scripts small.** Use Bash with `set -euo pipefail`, and start
  each script with a comment that says what it does and how to call it.

## Documentation

- **`guidebook/` is for people who use ShapeBit,** published to the Wiki and
  shapebit.software/docs. It describes what they see and do, in plain words;
  nothing about how it is built, and nothing that isn't built yet.
- **Developer documentation lives beside its code:** a feature's README in
  `packages/`, the OS as a whole in `distribution/README.md`. A README says
  only what the code and its comments can't: the intent, the structure, the
  rules, and what is planned. Comments cite the README that owns a fact.
