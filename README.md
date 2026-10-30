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

## How it works

### Build

`make image` ([scripts/image.sh](scripts/image.sh)) builds in two phases. It
signs with `SIGNING_KEY`: by default the development key that
[scripts/keys.sh](scripts/keys.sh) generates in `build/keys/` (`dev.key`,
`dev.crt`, named ShapeBit Development). It signs systemd-boot, the UKI, and the
TPM2 PCR values. `make release-key KEYS_DIR=<directory>` generates the release
key once (`release.key`, `release.crt`, named ShapeBit), which a build uses with
`SIGNING_KEY=release`; builds never generate it. CI
restores the same key from its `DEV_SIGNING_KEY` secret, so that installed systems
update across builds.

1. [Containerfile](Containerfile) builds the system: signed systemd-boot, the
   certificate to enroll, systemd-homed login support, the
   login screen, the desktop, and Files (Nautilus). The desktop's files come
   from its source tree (`DESKTOP_SRC`, by default `desktop/`), installed
   by its Makefile, and so do the packages it runs on, which it lists in
   `packages`. dnf installs no weak dependencies
   ([rootfs/usr/share/dnf5/libdnf.conf.d](rootfs/usr/share/dnf5/libdnf.conf.d)),
   so every package is in the image because a list names it or a named
   package requires it.
   Fedora has no Hyprland, so the build installs it from the third-party
   [sdegler/hyprland](https://copr.fedorainfracloud.org/coprs/sdegler/hyprland/)
   COPR for now; the repository is not left in the image.
2. [Containerfile.seal](Containerfile.seal) adds a signed UKI. Its
   command line pins the system's composefs digest, and it carries signed
   PCR 11 values for TPM2 unlock. The digest is computed from the built
   image, as `bootc install` computes it.

The sealed image is saved as `build/image.tar`.

### Installer medium

`make installer` builds the medium in the same two phases.
[Containerfile.installer](Containerfile.installer) adds, to the unsealed
system, the [installer](installer/), the
`cage` kiosk compositor that shows it, and the sealed system archive as the
payload; sealing then covers all of it with the medium's own signed UKI.
[scripts/medium.sh](scripts/medium.sh) writes the result to
`build/installer.raw`: an EFI System Partition and one unencrypted Btrfs
filesystem. The medium holds no secrets.

### Disk

`make disk` ([scripts/disk.sh](scripts/disk.sh)) installs the way a user does:
it boots the medium in QEMU with an empty disk of `DISK_SIZE` attached, checks
the medium ([tests/medium/](tests/medium/)), and runs the installer
through `installerctl`, the command-line client of the same D-Bus interface
that the UI uses. `make installer-vm` opens the same VM in a window instead.

The installer lays out the disk and installs with bootc's composefs backend.

| Partition  | Content                                                        |
| ---------- | -------------------------------------------------------------- |
| `esp`      | EFI System Partition: systemd-boot, UKIs, Secure Boot keys.    |
| `shapebit` | LUKS2 volume with one Btrfs filesystem, split into subvolumes. |

| Subvolume   | Mounted at  | Content                                             |
| ----------- | ----------- | --------------------------------------------------- |
| `@base`     | `/sysroot`  | composefs images and each deployment's `/etc`.      |
| `@machine`  | `/var`      | This device's state.                                |
| `@people`   | `/var/home` | systemd-homed homes (`/home` links to `/var/home`). |
| `@recovery` | not mounted | Reserved for recovery data.                         |

The LUKS2 partition has the x86-64 root partition type, so systemd finds and
unlocks it without machine-specific kernel arguments, which a UKI cannot carry.

### Boot and unlock

The chain starts with Fedora's shim, which Microsoft signed, so a PC keeps its
factory Secure Boot keys:

```text
firmware → Fedora's shim → signed systemd-boot → signed UKI → sealed system
```

Shim trusts our key only after a person enrolls its certificate, once per
machine, in shim's MOK manager. The first boot of the medium stops there; it
needs no password. [scripts/mok-enroll.sh](scripts/mok-enroll.sh) does the same
on the VM, whose firmware starts with Microsoft's keys.
[esp-shim](rootfs/usr/libexec/esp-shim) places shim on the medium and on the
installed disk; updates do not replace shim yet.

The installer gives the LUKS2 volume two key slots:

| Key slot     | Purpose                                                  |
| ------------ | -------------------------------------------------------- |
| TPM2         | Unlocks every normal boot, without a prompt.             |
| Recovery key | Shown once by the installer; saved to `build/recovery-key` by `make disk`. |

The TPM2 slot is bound to PCR 7 (the Secure Boot policy) and to PCR 11 values
signed by the same key. The medium and the installed system are signed
with that key, so the slot that the installer enrolls unlocks the
installed system, and a new UKI signed with the same key unlocks without
re-enrollment. If the TPM ever refuses, the console asks for a passphrase, and
the recovery key works there. The random key that opens the volume during the
installation never leaves memory and is removed before the installer finishes.

The installer marks the machine ID `uninitialized`, so the first boot generates
it and saves it once that boot completes.

The VM's EFI variables (`build/efivars.fd`) and TPM state (`build/tpm/`)
belong to the machine, which the medium and the installed disk share;
`make disk` resets them.

### Updates

Each build records `IMAGE_VERSION` in `/usr/lib/os-release` and in the
image's `org.opencontainers.image.version` label: in CI, the build date and
commit, such as `20261030_e0920a`; `dev` otherwise. Installed systems update
from `UPDATE_REF`, which the installer records:
`ghcr.io/shapebit-software/os:stable`.

`os-update.timer` runs `os-update`
([rootfs/usr/libexec/os-update](rootfs/usr/libexec/os-update)) soon after
boot and every 6 hours, except on metered connections; Settings' **Check
now** starts `os-update@now.service`, which a polkit rule lets the person at
the computer start. It downloads and stages a new build with
`bootc upgrade`, never restarts, and writes its state for the shell to
`/run/os-update/status.json`.

To update a VM from a local build, `make publish`
([scripts/publish.sh](scripts/publish.sh)) pushes the image to a local
registry container on the host, and the VM switches to it as
`DEV_UPDATE_REF`, through the host's `10.0.2.2`; bootc switches only to a
build other than the one running. That registry serves plain HTTP, so the VM
must mark it insecure first:

```bash
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf
bootc switch 10.0.2.2:5000/shapebit-os:dev
```

A staged build boots after a restart; `bootc rollback` returns to the
previous one. The TPM unlocks the new build
without re-enrollment, because its UKI carries PCR 11 values signed by the
same key, and each deployment's `/etc` carries the machine's own changes.
[tests/update/](tests/update/) checks all of this.

### Homes

Users are [systemd-homed](https://systemd.io/HOME_DIRECTORY/) homes. Each home
is a LUKS2-encrypted image, `/home/<user>.home` in `@people`, with Btrfs
inside, unlocked by its owner's password at login. The installer creates the
first owner, an administrator (`wheel`), directly on the installed disk.
systemd-homework leaves that Btrfs without SELinux labels, which keeps the
login screen out of the home; homed mounts it with `defcontext=` so it reads
as a home directory
([systemd-homed.service.d](rootfs/usr/lib/systemd/system/systemd-homed.service.d)).

### Login screen

[SDDM](https://github.com/sddm/sddm) shows the login screen on the first
virtual terminal; its greeter runs in Weston. The theme, in
[rootfs/usr/share/sddm/themes/login](rootfs/usr/share/sddm/themes/login), draws
the screen: the date and time, the accessibility and power menus, and the
person who signs in with their password. It lists systemd-homed users, uses
the Instrument Sans font (SIL Open Font License, in
[rootfs/usr/share/fonts/instrument-sans](rootfs/usr/share/fonts/instrument-sans),
since Fedora has no package of it), and draws its backdrop itself.

Signing in starts the desktop session: Hyprland with the ShapeBit shell, run
by UWSM. The login screen offers no other session, since Hyprland's own
entries are removed; without one it says so. Consoles are on the other
virtual terminals (Ctrl+Alt+F3). The
installer medium masks `sddm.service`, because the installer takes the screen
there.

To change the theme, run it in a window on a machine with SDDM:

```bash
sddm-greeter-qt6 --test-mode --theme rootfs/usr/share/sddm/themes/login
```

## Real hardware

The installer medium can install on an x86-64 UEFI machine with a TPM 2.0.
Legacy (CSM) boot must be off. This is a developer trial: every key is a
development key.

1. Build the medium:

   ```bash
   make installer ENGINE=docker
   ```

2. Write it to a USB drive of at least 16 GB. This erases the drive; check
   its name with `lsblk` first:

   ```bash
   sudo dd if=build/installer.raw of=/dev/sdX bs=4M conv=fsync status=progress
   ```

3. Leave Secure Boot on, with the factory keys. If the firmware's setup offers
   it, allow Microsoft's third-party UEFI certificate, which some Windows PCs
   turn off by default.
4. Boot the medium. Shim stops once with **Verification failed**, as our key is
   not trusted yet: choose **OK**, press a key, then **Enroll key from disk**,
   the partition, **enroll-this-key.cer**, **Continue**, **Yes**, and
   **Reboot**. No password is needed.
5. Follow the installer: language, keyboard layout, time
   zone, account, and the disk, with the confirmation that erases it. The
   network step offers nothing yet; skip it. Write down the recovery key that it shows: it is the only way
   in if the TPM refuses.
6. Remove the medium and restart. The disk unlocks with the TPM.
7. Switch to a console (Ctrl+Alt+F3), log in, connect to the network
   (`nmcli device wifi connect NAME --ask` for Wi-Fi), allow root to log in
   with `build/ssh/id_ed25519.pub`, and run the system checks from the
   development machine, with the settings given to the installer:

   ```bash
   make test-guest GUEST=ADDRESS IMAGE_DIGEST=sha256:... OWNER_NAME=... LOCALE=... KEYBOARD_LAYOUT=... TIME_ZONE=...
   ```

If something fails, `journalctl -b -u installer-backend.service` on the medium
shows the installation steps.

The first owner's home takes most of the free space, as systemd-homed sizes
it by default until the home storage policy exists; that can leave too little
room for updates.

## Development access

The images and disks contain no credentials. `make disk`, `make vm`, and
`make test` generate an SSH key in `build/ssh/` and pass its public key to the
VM as the systemd credential `ssh.authorized_keys.root`. `make disk` gives the
installer the first owner, `OWNER_NAME` (default `dev`) with the password in
`build/owner-password`, and the settings `LOCALE`, `KEYBOARD_LAYOUT`, and
`TIME_ZONE`. There is no root password.

## Layout

| Path                      | Purpose                                                             |
| ------------------------- | ------------------------------------------------------------------- |
| `Containerfile`           | The unsealed system.                                                |
| `Containerfile.installer` | The unsealed installer medium: the system, the installer, the payload. |
| `Containerfile.seal`      | Adds the signed UKI to an unsealed image.                           |
| `rootfs/`                 | Files copied verbatim into the image; paths mirror `/`.             |
| `scripts/`                | Keys, image build, medium, installation in QEMU, publishing, SSH.   |
| `tests/`                  | Checks in tmt plans and openQA modules: see [docs/Testing.md](docs/Testing.md). |
| `build/`                  | Generated outputs (ignored by Git).                                 |
| `desktop/`                | The desktop: compositor configuration, shell, and session.          |
| `installer/`              | The installer: backend, UI, and `installerctl`.                     |
| `docs/`                   | The documentation wiki, a separate repository (submodule).          |
| `.agents/`                | Skills for coding agents.                                           |

## Not yet implemented

- Trial boots with automatic rollback (systemd's Automatic Boot Assessment)
  and the boot health check. They wait on upstream: bootc's composefs backend
  does not yet add boot counters to its entries (planned through
  `/etc/kernel/tries`), and Fedora 44's SELinux policy does not yet let
  `systemd-bless-boot` rename entries on the ESP.
- NvPCR measurements. The same policy does not let `systemd-tpm2-setup` save
  its anchor credential to the ESP, so that unit fails on the installer
  medium. The TPM2 unlock policy (PCR 7 and PCR 11) does not use NvPCRs.
- A minimal signed recovery UKI.
- The home storage policy: guaranteed minimums, the machine reserve, and
  low-space states. systemd-homed's defaults size homes for now.

## Documentation

- [Architecture](https://github.com/shapebit-software/docs/wiki/Architecture)

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
