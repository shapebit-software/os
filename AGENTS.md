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

## Image

These rules cover the image: the `Containerfile`s, `Makefile`, `rootfs/`,
`scripts/`, and `tests/`, and any change in `desktop/` or `installer/` that the
image installs.

- **Verify with `make test`.** A change is done only when it passes; run
  `make test-release` too when it changes what a person sees. Add
  `ENGINE=docker` on hosts without Podman.
- **Prefer built-in tools.** Use what bootc, systemd, the Fedora base image, or
  QEMU already provide, such as `kargs.d`, systemd credentials, tmpfiles.d,
  sysusers.d, and presets. Add a package, script, or service only when nothing
  built in fits, and say why in a comment.
- **Make owns configuration.** Defaults live only in the `Makefile`. Scripts
  read them from the environment and fail fast on missing values
  (`: "${VAR:?}"`).
- **`rootfs/` mirrors the target filesystem.** Put vendor defaults under `/usr`.
  `/etc` and `/var` are machine state.
- **Every behavior gets a check.** See [docs/Testing.md](docs/Testing.md). Image
  content goes in `tests/image/`; the installer medium in `tests/medium/`;
  runtime behavior of the installed system in `tests/system/`; updates in
  `tests/update/`; what a person sees and does in `tests/openqa/`; logic that
  needs no machine in `tests/unit/`. Write checks in Python with pytest and
  Testinfra. The system under test gets nothing installed for a check: use the
  commands it ships. Only checks that need a host-side secret, such as the
  recovery key, go in `tests/host/`.
- **A bug becomes a regression test** at the lowest level that shows it.
- **Disks are installed by the installer.** `make disk` boots the installer
  medium and installs through it, so the tests cover what users run. Do not
  add a second way to produce an installed disk.
- **Never put credentials in the image or disk.** Development access goes
  through systemd credentials at VM launch. Private signing keys reach builds
  only as build secrets; only signed binaries and public keys enter the image.
- **Keep shell scripts small.** Use Bash with `set -euo pipefail`, and start
  each script with a comment that says what it does and how to call it.
