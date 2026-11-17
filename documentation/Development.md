# Development

How the [os repository](https://github.com/shapebit-software/os) builds the image and the
installer medium, installs them, and what the result does. To run the commands, see its
[README](https://github.com/shapebit-software/os#usage). How it is tested is in
[Testing](Testing.md).

## Features

Each feature is a folder of
[`packages/`](https://github.com/shapebit-software/os/tree/main/packages), and its README says
how it works, where it has more to say than its code: for example the
[installer](https://github.com/shapebit-software/os/tree/main/packages/installer) and its medium,
[updates](https://github.com/shapebit-software/os/tree/main/packages/updates),
[homes](https://github.com/shapebit-software/os/tree/main/packages/homes),
the [splash](https://github.com/shapebit-software/os/tree/main/packages/splash),
[colors](https://github.com/shapebit-software/os/tree/main/packages/colors),
the [login screen](https://github.com/shapebit-software/os/tree/main/packages/login),
the [desktop](https://github.com/shapebit-software/os/tree/main/packages/shell), and the
[package repositories](https://github.com/shapebit-software/os/tree/main/packages/repositories).
This page covers the OS as a whole.

## Build

`make image` ([distribution/image.sh](https://github.com/shapebit-software/os/blob/main/distribution/image.sh)) builds in two phases. It
signs with the keys of `SIGNING_KEY`: by default the development keys that
[distribution/keys.sh](https://github.com/shapebit-software/os/blob/main/distribution/keys.sh) generates in `build/keys/`.
`dev-secureboot.key` and `dev-secureboot.crt` (named ShapeBit Development) sign
systemd-boot and the UKI; `dev-pcr.key` signs the UKI's TPM2 PCR 11 values.
`make release-key KEYS_DIR=<directory>` generates the release keys once
(`release-secureboot.key`, `release-secureboot.crt`, named ShapeBit, and
`release-pcr.key`), which a build uses with `SIGNING_KEY=release`; builds never
generate them. The Candidate and Installer
workflows restore them from the `RELEASE_SECUREBOOT_KEY` and `RELEASE_PCR_KEY`
secrets, so that installed systems update across builds; the checks of pushes
and pull requests sign with throwaway development keys
([Signing Keys](Design-Security.md#signing-keys)).

1. [Containerfile](https://github.com/shapebit-software/os/blob/main/distribution/Containerfile) builds the system from
   ShapeBit's own packages, one per feature in
   [`packages/`](https://github.com/shapebit-software/os/tree/main/packages): each folder holds the
   feature's code, its install rules (`Makefile`), its tests, and its spec
   (`shapebit-<feature>`), whose `Requires` are the packages it runs on, each
   with its reason. The build reads every spec's `Requires` first, installs
   them, then builds every package at the image's version and commit, with
   every time in them the commit's, so the same commit gives the same
   packages; rpmlint checks them. `shapebit-system` requires every feature, and
   comes last. systemd-boot is signed there, with the certificate to enroll.
   dnf installs no weak dependencies, so every package is in the image
   because a spec requires it, or a package it requires does.
   Fedora has no Hyprland, so the build installs it from the third-party
   [sdegler/hyprland](https://copr.fedorainfracloud.org/coprs/sdegler/hyprland/)
   COPR for now; the repository ships turned off.
   The image also carries Flatpak with Flathub's remote, Distrobox, the
   speech recognition of dictation (sherpa-onnx), and llama.cpp's
   `llama-server` for the assistant. Fedora lacks the last two, so ShapeBit
   builds them as external packages at pinned versions, checked against their
   hashes, each in the feature that needs it (a folder with a `sources` file,
   such as `packages/dictation/sherpa-onnx/`), and publishes them in its own
   repository ([packages/repositories](https://github.com/shapebit-software/os/tree/main/packages/repositories)).
   The image ships no AI model: the models are extras, downloaded on the
   computer when the person chooses.
   Fedora's logos are replaced by `generic-logos`, as Fedora's trademark
   guidelines ask of systems made from it.
2. [Containerfile.seal](https://github.com/shapebit-software/os/blob/main/distribution/Containerfile.seal) adds a signed UKI. Its
   command line pins the system's composefs digest, and it carries signed
   PCR 11 values for TPM2 unlock. The digest is computed from the built
   image, as `bootc install` computes it.

The sealed image is saved as `build/image.tar`.

## Installer medium

`make installer` builds the medium, with the installer as a package; how is in
[packages/installer](https://github.com/shapebit-software/os/tree/main/packages/installer#medium).

## Disk

`make disk` ([distribution/vm/disk.sh](https://github.com/shapebit-software/os/blob/main/distribution/vm/disk.sh)) installs the way a user does:
it boots the medium in QEMU with an empty disk of `DISK_SIZE` attached, checks
the medium ([distribution/medium/](https://github.com/shapebit-software/os/blob/main/distribution/medium/)), and runs the installer
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
needs no password. [distribution/vm/mok-enroll.sh](https://github.com/shapebit-software/os/blob/main/distribution/vm/mok-enroll.sh) does the same
on the VM, whose firmware starts with Microsoft's keys.
[esp-shim](https://github.com/shapebit-software/os/blob/main/packages/boot/esp-shim) places shim on the medium and on the
installed disk; updates do not replace shim yet.

The installer gives the LUKS2 volume two key slots:

| Key slot     | Purpose                                                  |
| ------------ | -------------------------------------------------------- |
| TPM2         | Unlocks every normal boot, without a prompt.             |
| Recovery key | Shown once by the installer; saved to `build/recovery-key` by `make disk`. |

The TPM2 slot is bound to PCR 7 (the Secure Boot policy) and to PCR 11 values
signed by the PCR key. The medium and the installed system are signed
with the same keys, so the slot that the installer enrolls unlocks the
installed system, and a new UKI signed with the same keys unlocks without
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

How installed systems check for and stage updates (os-update) is in
[packages/updates](https://github.com/shapebit-software/os/tree/main/packages/updates).

To update a VM from a local build, `make publish`
([distribution/update/publish.sh](https://github.com/shapebit-software/os/blob/main/distribution/update/publish.sh)) pushes the image to a local
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
same PCR key, and each deployment's `/etc` carries the machine's own changes.
[distribution/update/](https://github.com/shapebit-software/os/blob/main/distribution/update/) checks all of this.

## Real hardware

[Installing ShapeBit](Install.md) is the guide for anyone. A medium built
locally is signed with the development keys, so a machine that installs it
enrolls those instead, and later updates from `stable` would need the
release keys enrolled too.

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

## Not yet implemented

- Trial boots with automatic rollback (systemd's Automatic Boot Assessment)
  and the boot health check. They wait on upstream: bootc's composefs backend
  does not yet add boot counters to its entries (planned through
  `/etc/kernel/tries`), and Fedora 45's SELinux policy (selinux-policy 45.23)
  does not yet let `systemd-bless-boot`, which runs as `init_t`, rename files
  on the ESP (`dosfs_t`). No upstream policy issue tracks this yet.
- NvPCR measurements. Since systemd 262, NvPCRs are initialized only from the
  initrd, through a PCR policy signed for it (`ukify --sign-initrd-pcrs`),
  with their definitions (`/usr/lib/nvpcr/*.nvpcr`) in the UKI. The UKI has
  neither, so `systemd-tpm2-setup` skips them. The TPM2 unlock policy (PCR 7
  and PCR 11) does not use NvPCRs.
- A minimal signed recovery UKI.
- The home storage policy: guaranteed minimums, the machine reserve, and
  low-space states. systemd-homed's defaults size homes for now.
