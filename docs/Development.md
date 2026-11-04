# Development

How the [os repository](https://github.com/shapebit-software/os) builds the image and the
installer medium, installs them, and what the result does. To run the commands, see its
[README](https://github.com/shapebit-software/os#usage). How it is tested is in
[Testing](Testing.md).

## Build

`make image` ([scripts/image.sh](https://github.com/shapebit-software/os/blob/main/scripts/image.sh)) builds in two phases. It
signs with `SIGNING_KEY`: by default the development key that
[scripts/keys.sh](https://github.com/shapebit-software/os/blob/main/scripts/keys.sh) generates in `build/keys/` (`dev.key`,
`dev.crt`, named ShapeBit Development). It signs systemd-boot, the UKI, and the
TPM2 PCR values. `make release-key KEYS_DIR=<directory>` generates the release
key once (`release.key`, `release.crt`, named ShapeBit), which a build uses with
`SIGNING_KEY=release`; builds never generate it. The Candidate workflow
restores it from its `RELEASE_KEY` secret, so that installed systems update
across builds; the checks of pushes and pull requests sign with a throwaway
development key ([Signing](Design-Lifecycle.md#signing)).

1. [Containerfile](https://github.com/shapebit-software/os/blob/main/image/Containerfile) builds the system: signed systemd-boot, the
   certificate to enroll, systemd-homed login support, the
   login screen, the desktop, and Files (Nautilus). The desktop's files come
   from its source tree (`DESKTOP_SRC`, by default `desktop/`), installed
   by its Makefile, and so do the packages it runs on, which it lists in
   `packages`. dnf installs no weak dependencies
   ([image/rootfs/usr/share/dnf5/libdnf.conf.d](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/share/dnf5/libdnf.conf.d)),
   so every package is in the image because a list names it or a named
   package requires it.
   Fedora has no Hyprland, so the build installs it from the third-party
   [sdegler/hyprland](https://copr.fedorainfracloud.org/coprs/sdegler/hyprland/)
   COPR for now; the repository is not left in the image.
   The image also carries Flatpak with Flathub's remote, Distrobox, the
   speech recognition of dictation (whisper.cpp with Whisper's small model,
   and sherpa-onnx), and llama.cpp's `llama-server` for the assistant, each
   built or downloaded at a pinned version and checked against its hash. The
   larger models are extras, downloaded on the computer.
2. [Containerfile.seal](https://github.com/shapebit-software/os/blob/main/image/Containerfile.seal) adds a signed UKI. Its
   command line pins the system's composefs digest, and it carries signed
   PCR 11 values for TPM2 unlock. The digest is computed from the built
   image, as `bootc install` computes it.

The sealed image is saved as `build/image.tar`.

## Installer medium

`make installer` builds the medium in the same two phases.
[Containerfile.installer](https://github.com/shapebit-software/os/blob/main/image/Containerfile.installer) adds, to the unsealed
system, the [installer](https://github.com/shapebit-software/os/blob/main/installer/), the
`cage` kiosk compositor that shows it, and the sealed system, as an OCI layout, as
the payload; sealing then covers all of it with the medium's own signed UKI.
[scripts/medium.sh](https://github.com/shapebit-software/os/blob/main/scripts/medium.sh) writes the result to
`build/installer.img`: an EFI System Partition and one unencrypted, compressed
Btrfs filesystem, 7 GiB in all, so that it fits a USB drive sold as 8 GB. The
medium holds no secrets.

## Disk

`make disk` ([scripts/disk.sh](https://github.com/shapebit-software/os/blob/main/scripts/disk.sh)) installs the way a user does:
it boots the medium in QEMU with an empty disk of `DISK_SIZE` attached, checks
the medium ([tests/medium/](https://github.com/shapebit-software/os/blob/main/tests/medium/)), and runs the installer
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

## Boot and unlock

The chain starts with Fedora's shim, which Microsoft signed, so a PC keeps its
factory Secure Boot keys:

```text
firmware → Fedora's shim → signed systemd-boot → signed UKI → sealed system
```

Shim trusts our key only after a person enrolls its certificate, once per
machine, in shim's MOK manager. The first boot of the medium stops there; it
needs no password. [scripts/mok-enroll.sh](https://github.com/shapebit-software/os/blob/main/scripts/mok-enroll.sh) does the same
on the VM, whose firmware starts with Microsoft's keys.
[esp-shim](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/libexec/esp-shim) places shim on the medium and on the
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

## Updates

Each build records `IMAGE_VERSION` in `/usr/lib/os-release` and in the
image's `org.opencontainers.image.version` label: in CI, the time the build
started, in UTC, such as `202610301530`; `dev` otherwise. Installed systems update
from `UPDATE_REF`, which the installer records:
`ghcr.io/shapebit-software/os:stable`.

`os-update.timer` runs `os-update`
([image/rootfs/usr/libexec/os-update](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/libexec/os-update)) soon after
boot and every 6 hours, except on metered connections; Settings' **Check
now** starts `os-update@now.service`, which a polkit rule lets the person at
the computer start. It downloads and stages a new build with
`bootc upgrade`, never restarts, and writes its state for the shell to
`/run/os-update/status.json`.

To update a VM from a local build, `make publish`
([scripts/publish.sh](https://github.com/shapebit-software/os/blob/main/scripts/publish.sh)) pushes the image to a local
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
[tests/update/](https://github.com/shapebit-software/os/blob/main/tests/update/) checks all of this.

## Homes

Users are [systemd-homed](https://systemd.io/HOME_DIRECTORY/) homes. Each home
is a LUKS2-encrypted image, `/home/<user>.home` in `@people`, with Btrfs
inside, unlocked by its owner's password at login. The installer creates the
first owner, an administrator (`wheel`), directly on the installed disk.
systemd-homework leaves that Btrfs without SELinux labels, which keeps the
login screen out of the home; homed mounts it with `defcontext=` so it reads
as a home directory
([systemd-homed.service.d](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/lib/systemd/system/systemd-homed.service.d)).

## Boot splash

[Plymouth](https://gitlab.freedesktop.org/plymouth/plymouth) shows the logo and
a spinner from the initramfs on, instead of boot messages
([kargs.d/30-splash.toml](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/lib/bootc/kargs.d/30-splash.toml));
it also asks for the recovery key when the TPM cannot unlock. The theme,
[image/rootfs/usr/share/plymouth/themes/boot](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/share/plymouth/themes/boot),
is Fedora's spinner theme with the logo. Errors still reach the console;
`Esc` shows the messages during boot.

Every step up to the desktop shares the splash's night color, `#1f1a3c`, so
none shows a black frame: the login screen and the installer take the screen
from Plymouth, which leaves its last picture until they draw
([sddm.service.d](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/lib/systemd/system/sddm.service.d));
the login screen fades in from the color and back to it after signing in;
the text console, briefly shown between them, has it as its background; and
Hyprland paints it until the shell's wallpaper fades in.

## Login screen

[SDDM](https://github.com/sddm/sddm) shows the login screen on the first
virtual terminal; its greeter runs in Hyprland, the desktop's compositor, with
its own configuration
([image/rootfs/usr/lib/sddm/compositor.lua](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/lib/sddm/compositor.lua)).
Weston, SDDM's usual compositor, shows it without a cursor. The theme, in
[image/rootfs/usr/share/sddm/themes/login](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/share/sddm/themes/login), draws
the screen: the date and time, the accessibility and power menus, and the
person who signs in with their password. It lists systemd-homed users, uses
the Instrument Sans font (SIL Open Font License, in
[image/rootfs/usr/share/fonts/instrument-sans](https://github.com/shapebit-software/os/blob/main/image/rootfs/usr/share/fonts/instrument-sans),
since Fedora has no package of it), and draws its backdrop itself.

Signing in starts the desktop session: Hyprland with the ShapeBit shell, run
by UWSM. The login screen offers no other session, since Hyprland's own
entries are removed; without one it says so. Consoles are on the other
virtual terminals (Ctrl+Alt+F3). The
installer medium masks `sddm.service`, because the installer takes the screen
there.

To change the theme, run it in a window on a machine with SDDM:

```bash
sddm-greeter-qt6 --test-mode --theme image/rootfs/usr/share/sddm/themes/login
```

## Real hardware

[Installing ShapeBit](Install.md) is the guide for anyone. A medium built
locally is signed with the development key, so a machine that installs it
enrolls that key instead, and later updates from `stable` would need the
release key enrolled too.

1. Build the medium, and write it to a USB drive of at least 8 GB, which
   erases it; check its name with `lsblk` first:

   ```bash
   make installer ENGINE=docker
   sudo dd if=build/installer.img of=/dev/sdX bs=4M conv=fsync status=progress
   ```

2. Install as the guide says.
3. To run the system checks on it, switch to a console (Ctrl+Alt+F3), log in,
   connect to the network (`nmcli device wifi connect NAME --ask` for
   Wi-Fi), allow root to log in with `build/ssh/id_ed25519.pub`, and run them
   from the development machine, with the settings given to the installer:

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

## Developing on ShapeBit

The immutable host ships with rootless Podman and Distrobox, so you can develop and install tools without touching the base system.

### Containers, not sandboxes

Distrobox exists for convenience and compatibility. It is **not** a security sandbox.

### Default container image

New containers start from the Fedora image matching the Fedora major version of your OS base.

### What's next

A dedicated ShapeBit OS development image is planned for a future release.

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
