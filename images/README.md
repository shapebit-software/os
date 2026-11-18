# Images

Every container image ShapeBit builds, one folder per image, named as it is
published, and `seal/`, the step that makes the bootable ones boot only as
built. They share one foundation, so the OS and the tools that work on it
have the same packages:

```
fedora-bootc
  └─ foundation        what ShapeBit's packages run on (their specs' Requires)
       ├─ development  + the tools that work on ShapeBit, and the desktop in a window
       └─ os           + ShapeBit's packages ─ seal ─▶ os
            └─ installer  + the installer and os as its payload ─ seal ─▶ installer
```

| Folder | Publishes | What it holds |
| --- | --- | --- |
| `foundation/` | `os/foundation` | Fedora's bootc image with every package that ShapeBit's packages require, from Fedora, the Hyprland COPR, and ShapeBit's repository; none of ShapeBit's own files. |
| `os/` | `os` | ShapeBit's packages, built from this commit and installed on the foundation, and the check that every file is packaged. |
| `installer/` | `os/installer` | The installer medium: the sealed OS with the installer and the OS as its payload, the disk it is written to, and its record. |
| `development/` | — | The development image, and the scripts that run commands and the desktop in it ([README](development/README.md)). |
| `seal/` | — | Pins an image's contents in a signed UKI, so that it boots only as built: the OS, and the installer. The keys it signs with are [release](../release/keys.md)'s. |

CI tags the sealed OS `os/candidate:<version>`; once its tests pass,
Release copies it, unchanged, to `os:<version>` and `os:stable`
([release](../release/README.md)). What each feature does is in its own
folder of [`packages/`](../packages/); how the built OS is tested is in
[`tests/`](../tests/README.md). The commands are in the
[README](../README.md#usage) at the root.

## Foundation

[packages/requires.sh](../packages/requires.sh) lists what the specs require;
the foundation installs it in one transaction, without weak dependencies, so
every package is there because a spec requires it. The OS and the development
image start from the same foundation (`FOUNDATION`), built by the same engine
(`ENGINE`).

- **Locally**, `make foundation` builds it, and the engine's cache keeps it
  until what the specs require changes.
- **In CI**, Candidate builds it without a cache, so a release gets Fedora's
  updates, and pushes it to `ghcr.io/shapebit-software/os/foundation`, tagged
  with the commit and as `latest`. Verification pulls `latest`, so its jobs
  don't install the packages again; it builds its own only when what the
  specs require changed.

## Build

`make image` ([seal.sh](seal/seal.sh)) builds in two phases:

1. [os/Containerfile](os/Containerfile) builds every package at the image's
   version and commit on the foundation, with every time in them the
   commit's, so a commit always gives the same packages; rpmlint checks them.
   [packaged.py](os/packaged.py) fails the build on a file under `/usr` that
   no RPM owns, or that differs from its RPM, compared with Fedora's bootc
   image. The image ships no AI model, and `generic-logos` replaces Fedora's,
   as Fedora's trademark guidelines ask.
2. [seal/Containerfile](seal/Containerfile) adds the signed UKI, whose
   command line pins the OS's composefs digest and which carries signed
   PCR 11 values ([packages/boot](../packages/boot/README.md)), with the keys
   of `SIGNING_KEY` ([release/keys.md](../release/keys.md)).

The result is `build/image.tar`.

## Installer

`make installer` builds the medium in the same two phases.
[installer/Containerfile](installer/Containerfile) adds, to the sealed
OS (`IMAGE`), the installer as a package
([packages/installer](../packages/installer/README.md)) at the image's
version, with what it requires, such as the `cage` kiosk compositor that
shows it, and the same sealed OS, as an OCI layout, as the payload. Of the
OS, the medium keeps only the features it boots and installs with, and every
license text; the desktop and its apps go, so that it fits beside the
payload. Sealing then replaces the OS's UKI with the medium's own, whose
composefs digest covers all of it. So the Installer workflow builds from the
released `os:<version>` alone, and no unsealed image is kept anywhere.

[medium.sh](installer/medium.sh) writes the result to `build/installer.img`:
an EFI System Partition and one unencrypted, compressed Btrfs filesystem,
7 GiB in all, so that it fits a USB drive sold as 8 GB. The medium holds no
secrets. Its record, `build/installer.img.json`
([provenance.py](installer/provenance.py)), names the OS it installs: its
version, which is also the installer's, and its image digest.
`make pull-installer` ([pull-installer.sh](installer/pull-installer.sh)) takes
a published one instead.

## Not yet implemented

- Trial boots with automatic rollback ([packages/updates](../packages/updates/README.md)).
- NvPCR measurements: since systemd 262 they are initialized only from the
  initrd, through a PCR policy signed for it (`ukify --sign-initrd-pcrs`),
  which the UKI doesn't have yet. The TPM policy doesn't use them.
- A minimal signed recovery UKI.
