# ShapeBit OS

ShapeBit OS is an image-based Linux desktop operating system built on Fedora:
a [bootc](https://bootc-dev.github.io/bootc/) container built on Fedora bootc 45,
and the installer medium that installs it to a disk that follows the
[Base System](https://shapebit.software/docs/) architecture. The system starts
to a login screen, which opens the [desktop](packages/shell/).

## Setup

```bash
git clone https://github.com/shapebit-software/os.git
```

## Development

The desktop and installer share one Fedora development container, configured
in `development/distrobox.ini`. Run these commands from the monorepo root:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file development/distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
```

Later, `make dev` enters it. Inside the container, `make run` runs the desktop
in a window (see [packages/shell](packages/shell/README.md)); for the
installer, follow [packages/installer](packages/installer/README.md). Both use the same installed tools and
libraries. Use the same container manager for creation and entry; replace
`docker` with `podman` if that is your host's engine.

Image builds and VM tests still use the host's container engine and QEMU;
see [Requirements](#requirements). The website lives in its own repository,
[shapebit-software/website](https://github.com/shapebit-software/website).

## Requirements

A Linux x86-64 host with KVM, a container engine, QEMU, Secure Boot capable
UEFI firmware, a software TPM, OpenSSH, and OpenSSL:

```bash
sudo dnf install podman skopeo make qemu-kvm edk2-ovmf swtpm openssh-clients openssl   # Fedora
sudo apt install podman skopeo make qemu-system-x86 ovmf swtpm openssh-client openssl  # Debian/Ubuntu
```

The default engine is `sudo podman`, because installing to a disk needs root.
To use Docker instead, add `ENGINE=docker` to any command.

## Usage

```bash
make static-checks # lint and validate, without building or running the code; inside `make dev`
make test-unit     # tests that need no image and no VM; inside `make dev`
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
| `distribution/`     | The OS image, assembled from those packages, and everything about it as a whole: its build (here), `release/`, `vm/`, and its checks: `content/`, `medium/`, `installed/`, `update/`, `openqa/` (see [documentation/Testing.md](documentation/Testing.md)). |
| `development/`       | Development: the container (`distrobox.ini`) and the desktop in a window (`make run`). |
| `documentation/`      | The documentation, published to the Wiki and the website.             |
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

- [Design](documentation/Design.md)
- [User Guide](documentation/User-Guide.md): [installing](documentation/Install.md) and
  [shortcuts](documentation/Shortcuts.md).
- [Development](documentation/Development.md): how the image, medium, and disk
  are made, boot and update, installing on real hardware, development access,
  and what is not implemented yet; [Testing](documentation/Testing.md).

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
