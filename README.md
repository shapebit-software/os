# ShapeBit OS

ShapeBit OS is an image-based Linux desktop operating system built on Fedora:
a [bootc](https://bootc-dev.github.io/bootc/) container built on Fedora bootc 45,
and the installer medium that installs it to a disk
([packages/installer](packages/installer/README.md#disk-layout)). The system starts
to a login screen, which opens the [desktop](packages/shell/).

## Setup

```bash
git clone https://github.com/shapebit-software/os.git
```

## Development

Every tool that works on ShapeBit, from lint and the unit tests to the image
builds and the VMs that check the built OS, is in
one development image, where `make` runs every target, after building it
([development](development/README.md)). Only the container engine runs
on the host, reached through its socket.

```sh
make check       # lint, validate, and the tests that need no image
make sync        # put a change into the running VM, or this computer on ShapeBit
make dev         # a shell in the development image
```

The website lives in its own repository,
[shapebit-software/website](https://github.com/shapebit-software/website).

## Requirements

A Linux x86-64 host with KVM, Git, Make, and Docker or Podman:

```bash
sudo dnf install git make podman      # Fedora
sudo apt install git make docker.io   # Debian/Ubuntu
```

One engine builds and runs every image. The default is `sudo podman`, because
building the installer medium needs root; its service's socket must be the
developer's to reach ([development](development/README.md)). To use
Docker instead, set it once: `export ENGINE=docker` in the shell's profile, or
`ENGINE=docker` on a command.

## Usage

```bash
make check              # lint, validate, and the unit and integration tests: all that needs no image
make test               # the unit and integration tests
make test-system        # build, test the image, install with the installer, and test a clone of the installed machine
make test-system-update # the same install, then update a clone to a new build and roll back
make test-e2e           # the medium itself, through its UI, with openQA; after `make installer`
make installer-vm       # boot the installer medium in a window, to install by hand
make vm                 # boot build/disk.raw in a window, its serial console on this terminal
make sync               # install this tree into the running VM, until it restarts (development/README.md)
make ssh                # root shell in the running VM (from another terminal)
make clean              # remove build/, including the disks, keys, and recovery key
make help               # all targets, with each test level's own
```

Settings are variables at the top of the [Makefile](Makefile), such as
`IMAGE`, `IMAGE_VERSION`, `DISK_SIZE`, `MEDIUM_SIZE`, and `SSH_PORT`.

## Layout

| Path         | Purpose                                                               |
| ------------ | --------------------------------------------------------------------- |
| `packages/`  | ShapeBit's own packages, one folder per feature: `apps`, `assistant`, `boot`, `capture`, `colors`, `dictation`, `downloads`, `extras`, `font`, `homes`, `installer`, `licenses`, `login`, `network`, `portal`, `release`, `repositories`, `shell`, `sound`, `splash`, `system` (requires them all), `updates`, `windows`; and the tools, which only the development image has: `packaging`, `linting`, `testing`. |
| `image/`     | How the images are built: one `Containerfile` with a stage per image (the foundation, the OS, the installer medium, the development image), sealing with the signed UKI, the signing keys (`keys/`), and what describes a build output ([image](image/README.md)). |
| `distribution/` | How a tested build reaches people, and what is published with it: `release.py`, every step of the workflows with GHCR and GitHub's releases; `sources/`, the source RPMs; `sbom/`, the SBOM ([distribution](distribution/README.md)). |
| `development/` | The development image's own scripts: `dev.sh`, which runs every `make` goal in it, and `make sync`, which puts a change into a running ShapeBit ([development](development/README.md)). |
| `guidebook/` | The guidebook for people who use ShapeBit, published to the Wiki and the website. |
| `.agents/`   | Skills for coding agents.                                             |
| `build/`     | Generated outputs (ignored by Git).                                   |

A folder in `packages/` is a feature and an RPM (`shapebit-<feature>`): its
code, its scripts, its tests, its install rules, and its spec, side by side.
Software that Fedora lacks is an external package inside the feature that
needs it, such as `packages/dictation/external/sherpa-onnx/` (a folder with a
`sources` file), built and published in ShapeBit's own repository
([packages/repositories](packages/repositories/README.md)). Its tests are in
`tests/LEVEL/`: `unit/`, `integration/`, `system/`, and `e2e/`, each run by
`make test-LEVEL` ([testing](packages/testing/README.md)).

## Documentation

- [Guidebook](guidebook/Home.md), for people who use ShapeBit.
- [Image](image/README.md): how the images are built and sealed;
  [keys](image/keys/README.md): what signs them;
  [testing](packages/testing/README.md): the tests, their levels, and the machines;
  [distribution](distribution/README.md): releases, sources, and the SBOM.
- Each feature's README in [`packages/`](packages/), where its code doesn't
  say it all: its goals, structure, and rules.

`guidebook/` is only for people who use ShapeBit. Developer documentation lives
beside the code it describes, and says only what the code and its comments
can't: the intent, the structure, and the rules.

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)

## License

Copyright Marcin Syngajewski. ShapeBit's own files are under open licenses, by
kind of file; [REUSE.toml](REUSE.toml) says which file is under which, and
[LICENSES/](LICENSES) holds their texts ([REUSE](https://reuse.software)):

| Files | License |
| ----- | ------- |
| Programs, such as the shell, the system, and updates | GPL-3.0-or-later |
| Code that other programs embed, such as the QML module Colors | LGPL-3.0-or-later |
| Configuration and snippets that people copy: `system/` folders, the compositor's configuration, the boot splash's theme, keys, the assistant's built-in skills | MIT |
| Documentation (`guidebook/`, READMEs) and artwork | CC-BY-SA-4.0 |
| Brand artwork: the logo and wordmark | [LicenseRef-Brand](LICENSES/LicenseRef-Brand.txt), no open license |

A new file of another kind gets an annotation in REUSE.toml; `make validate`
runs `reuse lint`, and each package's `License` must name the licenses of the
files it installs (packages/test_licenses.py). The software ShapeBit includes
keeps its own licenses ([guidebook/License.md](guidebook/License.md)).
