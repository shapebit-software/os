# Image

How the images are built from the packages of [`packages/`](../packages/README.md):
one [Containerfile](Containerfile), with a stage per image, and the steps
around it. The images share one foundation, so the OS and the tools that work
on it have the same packages:

```
fedora-bootc
  └─ foundation        what ShapeBit's packages run on (their specs' Requires)
       ├─ development  + the tools that work on ShapeBit
       └─ os           + ShapeBit's packages ─ seal ─▶ os
            └─ installer  + the installer and os as its payload ─ seal ─▶ installer
```

| Path | What it is |
| --- | --- |
| [Containerfile](Containerfile) | Every image, a stage each; built with `packages/` as the context and this folder as the context `image`. |
| [foundation.sh](foundation.sh) | Builds the foundation, or takes the published one made from the same recipe. |
| [seal.sh](seal.sh) | Builds a bootable image and seals it with its signed UKI; saves it as an OCI archive. |
| [packaged.py](packaged.py) | Fails the build on a file under `/usr` that no package owns, or that differs from its package. |
| [archive.py](archive.py) | What an image archive is (its digest, its labels) and the record of a medium made from one; the tests ([testing](../packages/testing/README.md)) and [distribution/](../distribution/README.md) read build outputs through it. |

CI tags the sealed OS `os/candidate:<version>`; once its tests pass,
Release copies it, unchanged, to `os:<version>` and `os:stable`
([distribution](../distribution/README.md)). How the built OS is tested is in
[`packages/testing/`](../packages/testing/README.md); the development image's own scripts are
in [`development/`](../development/README.md). The commands are in the
[README](../README.md#usage) at the root.

## Foundation

[requires.sh](requires.sh) lists what the specs require;
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

`make image` ([seal.sh](seal.sh)) builds in two phases:

1. The [Containerfile](Containerfile) builds every package at the image's
   version and commit on the foundation, with every time in them the
   commit's, so a commit always gives the same packages; rpmlint checks them.
   [packaged.py](packaged.py) fails the build on a file under `/usr` that
   no RPM owns, or that differs from its RPM, compared with Fedora's bootc
   image. The image ships no AI model, and `generic-logos` replaces Fedora's,
   as Fedora's trademark guidelines ask.
2. The seal stage of the [Containerfile](Containerfile) adds the signed UKI, whose
   command line pins the OS's composefs digest and which carries signed
   PCR 11 values ([packages/boot](../packages/boot/README.md)), with the keys
   of `SIGNING_KEY` ([signing](../signing/README.md)).

The result is `build/image.tar`.

## Installer

`make installer` builds the medium in the same two phases.
The installer stage of the [Containerfile](Containerfile) adds, to the sealed
OS (`IMAGE`), the installer as a package
([packages/installer](../packages/installer/README.md)) at the image's
version, with what it requires, such as the `cage` kiosk compositor that
shows it, and the same sealed OS, as an OCI layout, as the payload. Of the
OS, the medium keeps only the features it boots and installs with, and every
license text; the desktop and its apps go, so that it fits beside the
payload. Sealing then replaces the OS's UKI with the medium's own, whose
composefs digest covers all of it. So the Installer workflow builds from the
released `os:<version>` alone, and no unsealed image is kept anywhere.

[medium.sh](../packages/installer/tools/medium.sh) writes the result to `build/installer.img`:
an EFI System Partition and one unencrypted, compressed Btrfs filesystem,
7 GiB in all, so that it fits a USB drive sold as 8 GB. The medium holds no
secrets. Its record, `build/installer.img.json` ([archive.py](archive.py) `medium`),
names the OS it installs: its version, which is also the installer's, and its
image digest. `make pull-installer` (`distribution/release.py pull-installer`) takes
a published one instead.

## Not yet implemented

- Trial boots with automatic rollback ([packages/updates](../packages/updates/README.md)).
- NvPCR measurements: since systemd 262 they are initialized only from the
  initrd, through a PCR policy signed for it (`ukify --sign-initrd-pcrs`),
  which the UKI doesn't have yet. The TPM policy doesn't use them.
- A minimal signed recovery UKI.
