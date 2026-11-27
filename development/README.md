# Development

How to work on ShapeBit: one development image with every tool, where every
`make` target runs, for developers and CI alike: lint, validate, the unit
tests, the image builds, and the VMs and checks of the built OS. Changes are
seen on a real ShapeBit: a VM, or this computer when it runs ShapeBit. Only the container
engine runs on the host; its client in the image reaches it through its
socket ([image](../image/README.md)).

| File | What it is |
| --- | --- |
| [Containerfile](../image/Containerfile), its development stage | The development image: the foundation, so the OS's own packages, with what the installer builds with and what the tools run with ([packaging](../packages/packaging/README.md), [linting](../packages/linting/README.md), and [testing](../packages/testing/README.md)'s Requires). CI uses it too. |
| `dev.sh` | Runs a command in the image as the developer, in this repository, with KVM and the host's engine; with `--desktop`, with the host session's display and GPU, for a VM's window. |
| `sync.py` | `make sync`: installs this tree's features into a running ShapeBit. |
| `sync-apply.sh` | What `make sync` runs as root on that machine. |
| [simulator/](simulator/README.md) | `make simulate`: the tree's desktop in a window, on fake system services. |
| `vm-devices.rules` | Lets a VM borrow this computer's cameras and Bluetooth radios ([Devices](#devices)). |

Nothing here is installed in the image.

## One package at a time

`PACKAGE` limits `lint`, `validate`, every `test-*`, `sync`, `unsync`, and
`watch` to the packages it names; empty, the default, means every package:

```sh
make check PACKAGE=shell                 # its lint, validation, and tests
make watch PACKAGE="shell colors"        # only these, at every save
```

`make sync PACKAGE=colors` lays only Colors over `/usr`, and still refreshes
what requires it, such as the shell.

## Getting started

A computer needs KVM, Git, Make, OpenSSL, and Docker or Podman; nothing else
is installed on it. One engine, `ENGINE`, builds and runs every image; it is
rootful Podman (`sudo podman`) unless set otherwise, once, in the shell's
profile:

```sh
export ENGINE=docker   # in ~/.profile, on a host with Docker
make check
```

On the host, `make` builds the foundation and the development image the first
time and whenever they change, then runs itself there with the same goals and
settings: settings on its command line cross as they are, and those in the
environment, such as `OWNER_NAME`, when the Makefile sets them with `?=` or
they are test settings of `packages/testing/src/testing/machine.py` (`DEV_ENV`).
make's own `-o` does not cross; `SKIP=image` names the prerequisites that
count as built. In the image, `make` runs targets as they are. The image, the installer
medium, the disk, and the update test's builds are files under `build/`, made
again only when what they are made from changed: a file in `packages/` or
`image/`, a setting that goes into them, or the engine's image they start
from. A disk that booted since its install, as with `make vm`, is installed
again by `make test-system`; `rm build/disk.raw.json` installs again anyway.

The repository and the home folder have the same paths in the image as on the
host, so the paths that a command gives the engine are the host's; a command
that mounts a folder into a container uses one of the repository's, such as
`build/`, never the image's own `/tmp`. With Docker, the image's Docker client
takes the host's socket, which belongs to the `docker` group. With rootful
Podman, Podman in the image is the client of the host's Podman service, whose
socket the developer must reach: `sudo systemctl enable --now podman.socket`,
with a `SocketGroup=` of theirs in a drop-in for `podman.socket`.

This is the one supported way to work on ShapeBit. A Distrobox or Toolbox of
the image, or the tools installed on the host, would be a second setup that
falls behind the image.

### A shell in the image

`make dev` opens a shell in the development image, rebuilt first if it
changed, for commands that have no target, such as the installer's own
([packages/installer](../packages/installer/README.md#development)). `make`
there runs targets as they are.

### In an editor

VS Code and JetBrains open the same image as a dev container
(`.devcontainer/`), with Docker: `initialize.sh` builds it on the host and
writes `.env`, from which `compose.yaml` gives it what `dev.sh` does: the
repository at its host path, the host's network, KVM, and the host's Docker,
with their groups. Every target runs in the editor's terminal but those that
open a window, `vm`, `installer-vm`, and `simulate`, and `test-e2e`,
whose VNC server needs a network of its own; those run from a terminal on the
host. The editor rebuilds the container when asked after the image
changes.

## Where a change is seen

Each place is slower than the one before and closer to the OS that people
run; a change is seen in the first that can show it, and a bug's regression
test goes in the first that can catch it.

| Where | What it shows | How |
| --- | --- | --- |
| The development image | Lint, validation, unit and integration tests | `make check` |
| The simulator | The shell and what it shows, on fake system services | `make simulate`, `make watch MACHINE=simulator` |
| A running ShapeBit | The tree on the real system: services, login, sessions | `make vm`, `make watch` |
| The built image | Its files, a fresh install, updates (system tests) | `make test-system-image`, `make test-system`, `make test-system-update` |
| The built medium | Everything a person does, from installing on (`tests/e2e/`) | `make test-e2e` |

## Seeing a change on ShapeBit

A change is seen on a real ShapeBit, not built into an image: `make sync`
installs every feature of this tree, by its install rules, into a running
ShapeBit, and refreshes what runs from the features that changed. Each
feature whose files differ becomes a system extension of its name in
`/run/extensions`, which `systemd-sysext` lays over the image's `/usr`; the
next boot drops them, as `/run` is gone, and `make unsync` takes them away at
once, so the machine is its image again without restarting. `/etc` and `/var`
are machine state, which `make sync` leaves as they are; so is the image's
`os-release`, which names the OS that the extensions are for.

The machine is the VM, by default, or this computer when it runs ShapeBit:

```sh
make disk               # once: install a VM through the installer medium
make vm                 # the VM in a window; sign in as OWNER_NAME
make sync               # after each change; then look in the window
make sync MACHINE=local # on ShapeBit: into this computer's running system
make watch              # make sync at once, then after every save in packages/
make unsync             # the image again, without restarting
make update-vm          # a new image, such as a changed spec: update the VM to it
systemd-sysext status   # on the machine: which features are laid over /usr
```

The VM boots in full each time: QEMU (11.1) cannot save a VM whose GPU the
host renders for (virgl is not migratable), so there is no quick boot.
`make unsync` and the simulator leave few reasons to restart it.

`make sync` lays files over `/usr`, which is enough for a feature's own
files. What only a new image brings, such as a package that a spec now
requires, `make update-vm` brings: it builds the image, serves it from the
local update registry, and updates the running VM to it, as an installed
system updates, then restarts it. That takes minutes rather than a new
medium and install, and the install stays: its owner, keys, and TPM.

### Devices

The VM in a window plays and records through this computer's PipeWire, its
speakers and microphone, which this computer keeps using too. It also
borrows this computer's USB devices of the kinds that `DEVICES` names, found
by their class as they are plugged in: `camera`, the default, and
`bluetooth`. While the VM has one, this computer does not: with Bluetooth,
its own headphones disconnect.

```sh
make vm                               # with the camera
make vm DEVICES="camera bluetooth"    # with the Bluetooth radio too
make vm DEVICES=                      # with none
make devices DEVICES=                 # while it runs: give them all back
make devices                          # and lend the camera again
```

A USB device opens only for root unless a rule says otherwise, so this
computer lets the group `kvm`, whose members run VMs, open cameras and
Bluetooth radios, once ([vm-devices.rules](vm-devices.rules)):

```sh
sudo cp development/vm-devices.rules /etc/udev/rules.d/70-vm-devices.rules
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=usb
```

Then `make sync` refreshes the running services of the features that
changed and of the features that require them (their specs): each one
reloads, if its unit says how (`ExecReload=`), or else restarts. The shell
reloads its files in place (`shell.service`), the compositor its
configuration (a drop-in for UWSM's `wayland-wm@.service`). A service that a
feature only extends with a drop-in, such as the login screen or
systemd-homed, only reloads, as restarting it would end people's sessions; a
new service starts with the next session. Nothing in `sync-apply.sh` names a
feature: a feature's units say how it takes a change.

On this computer, `make sync` reaches the system through the engine, which is
root on the host; it refuses a computer that does not run ShapeBit. Change
here only what restarts cleanly, such as the shell, apps, and session
services, and preferably signed in as a second person, whose home the code
under test may change. What can keep a computer from starting or signing in,
such as login, boot, updates, and the installer, is changed in the VM. The
features run on the dependencies of the installed system, not of this tree:
a change to a spec's `Requires` is seen after `make image` and an update.

To develop on ShapeBit, enable its Podman service for the developer, as on
any host (Getting started); Git and Make are in the system.

## Trying things in the desktop

- Welcome opens until it is finished or skipped (`welcomed` in
  `~/.config/desktop/settings.json`). Settings live in `~/.config/desktop/`,
  the downloads queue's state in `~/.local/state/desktop/downloads.json`.
- To try each portal, install [ASHPD Demo](https://flathub.org/apps/com.belmoussaoui.ashpd.demo)
  from Settings > Apps; as a Flatpak, it asks as other apps do.
- Another assistant model can be listed in `~/.config/assistant/models.json`, such as
  `{"id": "dev", "name": "Dev", "where": "online", "url": "http://10.0.2.2:8080/v1"}`;
  the VM reaches the host at 10.0.2.2.
