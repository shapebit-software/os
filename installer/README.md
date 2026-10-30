# ShapeBit installer

The installer of ShapeBit OS: a Qt Quick frontend and a privileged backend
that erase one disk and install the system on it, following the
[Installation](https://shapebit.software/docs/) architecture.

It runs from the installer medium, which the
[image](../README.md) builds
(`make installer`) and tests (`make test`).

## How it works

```text
installer (UI, user "installer", under cage)
    │  D-Bus, system bus: interface/installer.xml
    ▼
installer-backend (root)  →  sfdisk, cryptsetup, bootc, systemd-cryptenroll, homectl
```

- The **UI** walks through eight steps: welcome and language, keyboard
  layout, network, time zone, account, disk and final confirmation,
  installation, and finish. It has no privileges.
- The **backend** validates the plan and runs the installation in six phases:
  `validating → preparing → creating-storage → installing-system →
  configuring → verifying`. The disk is untouched until `creating-storage`,
  and **Cancel** works until then.
- The owner password and the recovery key cross through one-shot channels
  that the backend creates (file descriptors passed over D-Bus), never inside
  D-Bus messages.
- A disk is identified by its WWN or serial number. The backend resolves that
  identity again when it accepts the plan, when the user confirms, and
  immediately before it erases the disk.

On the target disk the backend creates the layout of the
[Base System](https://shapebit.software/docs/): an EFI System Partition and a
LUKS2 volume with Btrfs subvolumes. It installs the system from the archive on
the medium with bootc, enrolls a recovery key and this machine's TPM2 (PCR 7
and signed PCR 11), and creates the first owner with systemd-homed directly on
the target. For that, it gives the installed system its machine ID and runs
the medium's systemd-homed on the target's home storage and state, so the
owner's record belongs to the installed system. Before it reports success, it
checks the result and unlocks the volume once with each key.

## Development

From the monorepo root, create and enter the shared Fedora development
environment (see the [setup instructions](https://github.com/shapebit-software/os#development)).
Then build and test:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
cd installer
cmake -S . -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

To try the UI without touching a disk, run the simulated backend, which fakes
disks and progress on the session bus:

```sh
build/backend/installer-backend --simulate &
build/ui/installer --session
```

A first owner named `fail` makes the simulated installation fail, and the
Wi-Fi password `wrong` is refused.
`INSTALLER_SCREENSHOTS=<directory>` makes the UI test save a picture of each
page.

`installerctl` is a command-line client of the same D-Bus interface:

```sh
build/ctl/installerctl --session disks
```

To install for real, in a VM, use `make installer-vm` in the image repository.

## Layout

| Path         | Purpose                                                        |
| ------------ | -------------------------------------------------------------- |
| `interface/` | The D-Bus interface; the adaptor and proxy are generated.      |
| `backend/`   | `installer-backend`: validation, secrets, installation steps.  |
| `ui/`        | `installer`: the Qt Quick pages.                               |
| `ctl/`       | `installerctl`: command-line client for tests and debugging.   |
| `data/`      | systemd units, the D-Bus policy, and the UI's system user.     |
| `tests/`     | Backend rules, the D-Bus interface, and the pages.             |

## Not yet implemented

- Wi-Fi on a real machine: the backend reports no networks, so the network
  step offers none. Only the simulated backend lists and connects.
- The hostname. The locale, the keyboard layout (XKB, and the console keymap
  where kbd ships one for it), and the time zone are written to the installed
  system.
- Dead keys and Compose in the installer itself, with a chosen keyboard
  layout (see `ui/keyboard.h`).
- The Recovery Kit: the owner's home recovery key, QR code, print, and
  encrypted export. Only the device recovery key is shown, as text.
- Labelling external disks, and refusing ambiguous multipath devices.
- Resuming after the backend restarts, and the durable
  installation-complete marker.
- A firmware boot entry for the installed system: it starts through the
  disk's fallback boot loader once the medium is removed.
