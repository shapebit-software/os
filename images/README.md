# Images

Every container image ShapeBit builds, one folder per step. They share one
foundation, so the OS and the tools that work on it have the same packages:

```
fedora-bootc
  └─ foundation        what ShapeBit's packages run on (their specs' Requires)
       ├─ development  + the tools that work on ShapeBit, and the desktop in a window
       └─ system       + ShapeBit's packages: the unsealed OS
            └─ seal    + the signed UKI, which pins the system's contents
                         (the installer medium is sealed the same way)
```

| Folder | What it holds |
| --- | --- |
| `foundation/` | Fedora's bootc image with every package that ShapeBit's packages require, from Fedora, the Hyprland COPR, and ShapeBit's repository; none of ShapeBit's own files. |
| `development/` | The development image, and the scripts that run commands and the desktop in it ([README](development/README.md)). |
| `system/` | The OS image before it is sealed: ShapeBit's packages, built from this commit and installed on the foundation, and the check that every file is packaged. |
| `seal/` | Pins an image's contents in a signed UKI, so that it boots only as built: the system, and the installer medium. With the script that builds both phases, and the signing keys. |

CI tags the sealed system `os/candidate:<version>`; once its tests pass,
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

1. [system/Containerfile](system/Containerfile) builds every package at the image's
   version and commit on the foundation, with every time in them the
   commit's, so a commit always gives the same packages; rpmlint checks them.
   [packaged.py](system/packaged.py) fails the build on a file under `/usr` that
   no RPM owns, or that differs from its RPM, compared with Fedora's bootc
   image. The image ships no AI model, and `generic-logos` replaces Fedora's,
   as Fedora's trademark guidelines ask.
2. [seal/Containerfile](seal/Containerfile) adds the signed UKI, whose
   command line pins the system's composefs digest and which carries signed
   PCR 11 values ([packages/boot](../packages/boot/README.md)).

The result is `build/image.tar`. `make installer` builds the medium
([packages/installer](../packages/installer/README.md#medium)).

## Signing keys

A build is signed with two keys of `SIGNING_KEY`, so that each can be
replaced on its own:

| Key | Signs | If it leaks |
| --- | --- | --- |
| Secure Boot (`*-secureboot.key`, `.crt`, the MOK people enroll) | systemd-boot and the UKI | Its holder can boot their code on every machine that enrolled it; without the PCR key, the TPM still refuses to unlock the disk. |
| PCR (`*-pcr.key`) | The expected PCR 11 values in each UKI | Alone, nothing boots. |

- **Development keys** (`dev-*`, "ShapeBit Development") are generated in
  `build/keys/` by [keys.sh](seal/keys.sh). The checks of pushes and pull requests
  use throwaway ones. They are trusted only by the developer's machines.
- **Release keys** ("ShapeBit") sign every candidate, so every release.
  `make release-key KEYS_DIR=<directory>` generates them once; builds never
  do. They are the secrets `RELEASE_SECUREBOOT_KEY` and `RELEASE_PCR_KEY` of
  the GitHub environment **Signing**, used only by the build jobs of the
  Candidate and Installer workflows on `main`, and removed from the runner
  before tests run ([test_workflows.py](../.github/test_workflows.py)).
  Inside a build, only the steps that sign see them, as build secrets.
- Promotion never re-signs, so a development build can never become a
  release. Whoever can approve a release can ship code to every computer.
- Both are RSA-2048, which shim and every TPM accept. Firmware and shim don't
  check certificate dates; replacing a key retires it.
- An installer enrolls the TPM with the PCR key of its own UKI, so an
  installer and the release it carries share the PCR key.

**Limit.** During those builds the keys are files on a GitHub-hosted runner,
which also runs the packages' scripts. Next: sign in jobs that receive only
unsigned binaries, or through PKCS#11 from a KMS or HSM (`sbsign` and `ukify`
support it); it takes two rounds, because the signed systemd-boot is in
`/usr`, inside the digest that the UKI pins. The goal is an offline root key
that delegates to release, boot, PCR, and repository keys in hardware-backed
storage.

**Rotation** (planned; it needs code in a release that runs on every machine):

- *PCR key*: release a UKI whose PCR 11 values are signed with both keys
  (`ukify` takes several `--pcr-private-key`), with a one-time service that
  enrolls a TPM slot for the new key with `systemd-cryptenroll` and wipes the
  old one. Once every machine has run it, sign with the new key only. A
  machine that missed it asks for its recovery key once.
- *Secure Boot key*: release a build, still signed with the old key, that
  queues the new certificate with `mokutil --import`, which the person
  confirms at the next boot. The same release must enroll a TPM slot for the
  new PCR 7 value (predicted with `systemd-pcrlock`), since shim measures the
  certificate into PCR 7. Then sign with the new key and queue removal of the
  old one (`mokutil --delete`).
- *After a Secure Boot key leak*, nobody can revoke it remotely: every MOK
  change needs the person at the machine. Also queue the old certificate in
  shim's deny list (`mokutil --mokx --import`). This is why the keys stay off
  runners as much as possible and have an offline backup.

## Not yet implemented

- Trial boots with automatic rollback ([packages/updates](../packages/updates/README.md)).
- NvPCR measurements: since systemd 262 they are initialized only from the
  initrd, through a PCR policy signed for it (`ukify --sign-initrd-pcrs`),
  which the UKI doesn't have yet. The TPM policy doesn't use them.
- A minimal signed recovery UKI.
