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

Every tool that works on ShapeBit, from lint and the unit tests to the
desktop in a window and the VMs that check the built OS, is in one
development image, which `make` builds and enters by itself
([development](images/development/README.md)). Only the container engine, which
builds the OS image, runs on the host.

```sh
make test-unit   # the unit tests
make run         # the desktop in a window
make dev         # a shell in the development image
```

The website lives in its own repository,
[shapebit-software/website](https://github.com/shapebit-software/website).

## Requirements

A Linux x86-64 host with KVM, Git, Make, OpenSSL, and Docker or Podman:

```bash
sudo dnf install git make openssl podman      # Fedora
sudo apt install git make openssl podman      # Debian/Ubuntu
```

One engine builds and runs every image. The default is `sudo podman`, because
building the installer medium needs root. To use Docker instead, set it once:
`export ENGINE=docker` in the shell's profile, or `ENGINE=docker` on a command.

## Usage

```bash
make static-checks # lint and validate, without building or running the code
make test-unit     # tests that need no image and no VM
make test          # build, test the image, install with the installer, and check a clone of the installed machine
make test-update   # the same install, then update a clone to a new build and roll back
make test-release  # the medium itself, through its UI, with openQA; after `make installer`
make installer-vm  # boot the installer medium in a window, to install by hand
make vm            # boot build/disk.raw with the serial console on this terminal
make ssh           # root shell in the running VM (from another terminal)
make clean         # remove build/, including the disks, keys, and recovery key
make help          # all targets
```

Settings are variables at the top of the [Makefile](Makefile), such as
`IMAGE`, `IMAGE_VERSION`, `DISK_SIZE`, `MEDIUM_SIZE`, and `SSH_PORT`.

## Layout

| Path         | Purpose                                                               |
| ------------ | --------------------------------------------------------------------- |
| `packages/`  | ShapeBit's own packages, one folder per feature: `apps`, `assistant`, `boot`, `capture`, `colors`, `dictation`, `downloads`, `extras`, `font`, `homes`, `installer`, `licenses`, `login`, `network`, `portal`, `release`, `repositories`, `screen-sharing`, `shell`, `sound`, `splash`, `system` (requires them all), `updates`, `windows`. |
| `images/`    | How the images are built, one folder per image: `foundation/`, which the others start from; `os/`, the OS; `installer/`, the installer medium; `development/`, with the desktop in a window (`make run`); and `seal/`, the signed UKI of `os` and `installer` ([images](images/README.md)). |
| `tests/`     | How the built OS is checked: `vm/` (the machines), `checks/` (tmt), `openqa/` (the UI) ([tests](tests/README.md)). |
| `release/`   | How a tested build is published and trusted: its tags, sources, SBOM, notes, and signing keys ([release](release/README.md), [keys](release/keys.md)). |
| `guidebook/` | The guidebook for people who use ShapeBit, published to the Wiki and the website. |
| `.agents/`   | Skills for coding agents.                                             |
| `build/`     | Generated outputs (ignored by Git).                                   |

A folder in `packages/` is a feature and an RPM (`shapebit-<feature>`): its
code, its scripts, its tests, its install rules, and its spec, side by side.
Software that Fedora lacks is an external package inside the feature that
needs it, such as `packages/dictation/sherpa-onnx/` (a folder with a
`sources` file), built and published in ShapeBit's own repository
([packages/repositories](packages/repositories/README.md)). `test_*.py` are
unit tests (`make test-unit`); `check_*.py` check the built OS
(`make test-image`, `make test`).

## Documentation

- [Guidebook](guidebook/Home.md), for people who use ShapeBit.
- [Images](images/README.md): how the images are built and sealed;
  [keys](release/keys.md): what signs them;
  [testing](tests/README.md): how the built OS is installed and tested;
  [releases](release/README.md).
- Each feature's README in [`packages/`](packages/), where its code doesn't
  say it all: its goals, structure, and rules.

`guidebook/` is only for people who use ShapeBit. Developer documentation lives
beside the code it describes, and says only what the code and its comments
can't: the intent, the structure, and the rules.

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
