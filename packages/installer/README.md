# ShapeBit installer

The installer of ShapeBit OS: a Qt Quick frontend and a privileged backend
that erase one disk and install the system on it.

It runs from the installer medium, which the
[image](../../README.md) builds
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

On the target disk the backend creates the [disk layout](#disk-layout). It
installs the system from the archive on
the medium with bootc, enrolls a recovery key and this machine's TPM2 (PCR 7
and signed PCR 11), and creates the first owner with systemd-homed directly on
the target. For that, it gives the installed system its machine ID and runs
the medium's systemd-homed on the target's home storage and state, so the
owner's record belongs to the installed system. Before it reports success, it
checks the result and unlocks the volume once with each key.

## Disk layout

```text
GPT
├── esp        EFI System Partition: shim, signed systemd-boot and UKIs; no secrets
└── shapebit   LUKS2, with the x86-64 root partition type, so systemd finds it
    └── Btrfs
        ├── @base      /sysroot: the composefs images, and each release's /etc
        ├── @machine   /var: this computer's state
        ├── @people    /var/home: the systemd-homed homes (packages/homes)
        └── @recovery  not mounted; reserved for recovery
```

Homes are in `@people`, not `@machine`, so that a reset can wipe the
computer's state and keep the homes. Each release keeps its own `/etc` and
carries local changes forward on update. The installer sizes the first
owner's home to leave the computer its reserve
([packages/homes](../homes/README.md)), and marks the machine ID
`uninitialized`, so the first boot generates it. The random key that opens the
volume during the installation never leaves memory.

## Medium

`make installer` builds the medium in the same two phases as the image.
[medium/Containerfile](medium/Containerfile) adds, to the sealed
system (`IMAGE`), the installer as a
package ([installer.spec](installer.spec)) at the
image's version, with what it requires, such as the `cage` kiosk compositor that
shows it, and the same sealed system, as an OCI layout, as
the payload; sealing then replaces the system's UKI with the medium's own, whose
composefs digest covers all of it. So the Installer workflow builds from the
released `os:<version>` alone, and no unsealed image is kept anywhere. The
medium's record, `build/installer.img.json`, names the system it installs: its
version, which is also the installer's, and its image digest.
[medium/medium.sh](medium/medium.sh) writes the result to
`build/installer.img`: an EFI System Partition and one unencrypted, compressed
Btrfs filesystem, 7 GiB in all, so that it fits a USB drive sold as 8 GB. The
medium holds no secrets.

## Development

From the monorepo root, create and enter the shared Fedora development
environment (see the [setup instructions](https://github.com/shapebit-software/os#development)).
Then build and test:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file development/distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
cmake -S installer -B build/installer -G Ninja
cmake --build build/installer
ctest --test-dir build/installer --output-on-failure
```

To try the UI without touching a disk, run the simulated backend, which fakes
disks and progress on the session bus:

```sh
build/installer/backend/installer-backend --simulate &
build/installer/ui/installer --session
```

A first owner named `fail` makes the simulated installation fail, and the
Wi-Fi password `wrong` is refused.
`INSTALLER_SCREENSHOTS=<directory>` makes the UI test save a picture of each
page.

`installerctl` is a command-line client of the same D-Bus interface:

```sh
build/installer/ctl/installerctl --session disks
```

To install for real, in a VM, use `make installer-vm` from the repository root.

## Layout

| Path         | Purpose                                                        |
| ------------ | -------------------------------------------------------------- |
| `interface/` | The D-Bus interface; the adaptor and proxy are generated; its test. |
| `backend/`   | `installer-backend`: validation, secrets, installation steps; its unit, D-Bus policy, and tests. |
| `ui/`        | `installer`: the Qt Quick pages; its unit, system user, and tests. |
| `ctl/`       | `installerctl`: command-line client for tests and debugging.   |
| `units.preset` | Enables both programs' units.                                |

Each part's tests sit beside its code: `tst_*.cpp` and `test_*` files.

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
