# ShapeBit OS

ShapeBit OS is an image-based Linux desktop operating system built on Fedora:
a [bootc](https://bootc-dev.github.io/bootc/) container built on Fedora bootc 44,
and the installer medium that installs it to a disk that follows the
[Base System](https://shapebit.software/docs/) architecture. The system starts
to a login screen, which opens the [desktop](desktop/).

## Setup

```bash
git clone --recurse-submodules https://github.com/shapebit-software/os.git
```

## Development

The desktop and installer share one Fedora development container, configured
in the root `distrobox.ini`. Run these commands from the monorepo root:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
```

Inside the container, change into `desktop/` or `installer/` and follow that
project's development instructions. Both use the same installed tools and
libraries. Use the same container manager for creation and entry; replace
`docker` with `podman` if that is your host's engine.

Image builds and VM tests still use the host's container engine and QEMU;
see [Requirements](#requirements). The website lives in its own repository,
[shapebit-software/website](https://github.com/shapebit-software/website).

## Requirements

A Linux x86-64 host with KVM, a container engine, QEMU, Secure Boot capable
UEFI firmware, a software TPM, OpenSSH, and OpenSSL:

```bash
sudo dnf install podman make qemu-kvm edk2-ovmf swtpm openssh-clients openssl   # Fedora
sudo apt install podman make qemu-system-x86 ovmf swtpm openssh-client openssl  # Debian/Ubuntu
```

The default engine is `sudo podman`, because installing to a disk needs root.
To use Docker instead, add `ENGINE=docker` to any command.

## Usage

```bash
make test-unit     # isolated unit tests, without a VM
make test          # build, check, install with the installer, and check a clone of the installed machine
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
| `image/`     | The Containerfiles of the system, the medium, and the seal, and `rootfs/`, copied verbatim into the image. |
| `desktop/`   | The desktop: compositor configuration, shell, and session.            |
| `installer/` | The installer: backend, UI, and `installerctl`.                       |
| `scripts/`   | Keys, image build, medium, installation in QEMU, publishing, SSH.     |
| `tests/`     | Checks in tmt plans and openQA modules: see [docs/Testing.md](docs/Testing.md). |
| `docs/`      | The documentation wiki, a separate repository (submodule).            |
| `.agents/`   | Skills for coding agents.                                             |
| `build/`     | Generated outputs (ignored by Git).                                   |

## Documentation

- [Building](docs/Building.md): how the image, medium, and disk are made, boot and
  update, installing on real hardware, development access, and what is not
  implemented yet.
- [Testing](docs/Testing.md)
- [Architecture](https://github.com/shapebit-software/docs/wiki/Architecture)

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
