# Security

This page describes how the OS protects the device and its data.

## Disk Encryption

Every machine's volume is encrypted with **LUKS2**.

On a normal boot, the volume unlocks itself automatically using the
device's **TPM2** chip — no password needed. Every device also has an
independent **recovery key**, kept separately, that can unlock the
volume if the TPM path ever fails.

Each person's home is encrypted again, inside that volume, and unlocks only
with its owner's password at login.

## TPM Unlock Policy

The TPM only releases the disk key when the machine's boot state looks
right. It checks two things, using two **PCRs** (Platform Configuration
Registers — measurements the firmware takes during boot):

| PCR | Checks | Behavior |
| --- | --- | --- |
| **PCR 7** | Secure Boot policy | Must match a fixed, expected value. |
| **PCR 11** | The running OS UKI (Unified Kernel Image) | Must match one of a set of *signed, approved* measurements. |

PCR 11 accepts any measurement covered by a valid signature, rather
than one fixed value. This means an approved OS update can ship a new,
different measurement without the device needing to be re-enrolled
with the TPM after every release.

PCR 0, 2, and 14 are **not** checked by the default policy.

If the TPM path fails, the recovery key is required; see [Recovery](Design-Recovery.md).

## Signing Keys

Each build is signed with two keys, so that each can be replaced on its own:

| Key | Files | Signs | If it leaks |
| --- | --- | --- | --- |
| **Secure Boot** | `release-secureboot.key`, `release-secureboot.crt` (the MOK that each person enrolls) | systemd-boot and the UKI | Its holder can boot their own code on every machine that enrolled it. Without the PCR key, the TPM still refuses to unlock the disk for it. |
| **PCR** | `release-pcr.key` | The expected PCR 11 values in each UKI | Alone, nothing boots: a UKI must still pass Secure Boot, and turning Secure Boot off changes PCR 7. |

Development builds use `dev-*` keys of the same two kinds
([Signing](Design-Lifecycle.md#signing)). Both are RSA-2048, which is what shim
and every TPM2 accept. Firmware and shim do not check certificate dates, so the
certificate's 10 years do not retire the key; replacing it does.

The installer enrolls the TPM2 slot with the PCR key of its own UKI, so an
installer and the release it carries must share the PCR key. The Installer
workflow's install tests show that they do.

### Protection

- The release keys are the secrets `RELEASE_SECUREBOOT_KEY` and
  `RELEASE_PCR_KEY` of the GitHub environment **Signing**, which only the
  build jobs of the Candidate and Installer workflows use, and only on `main`.
- They are on the runner only from the step that restores them until the last
  build that signs; tests run after they are removed
  ([tests/unit/test_workflows.py](https://github.com/shapebit-software/os/blob/main/tests/unit/test_workflows.py)).
  Inside a build, only the steps that sign see them, as build secrets that no
  image layer keeps. Only signed binaries and public keys enter the image.
- The image that the update test moves on to (`os/candidate:<version>-update`)
  is release-signed too, because the test machine trusts only the release
  keys. It stays private and is never released.

**Limit.** During those builds the keys are files on a GitHub-hosted runner,
which also runs the packages' scripts (Supply Chain, below). The next step is
to sign so that no runner holds them: in jobs of their own that receive only
unsigned binaries, or through PKCS#11 from a KMS or HSM, which `sbsign` and
`ukify` both support. It takes two rounds, because the signed systemd-boot is
in `/usr`, inside the composefs digest that the UKI pins.

### Rotation

> **Planned, not built.** These steps need code in a release that runs on
> every machine.

**The PCR key**, planned or after a leak:

1. Generate a new `release-pcr.key`.
2. Release a build whose UKI carries PCR 11 values signed with both keys
   (`ukify` takes several `--pcr-private-key`) and embeds the new public key.
   It runs a one-time service that, while the old slot unlocks the disk,
   enrolls a TPM2 slot bound to the new public key with
   `systemd-cryptenroll`, then wipes the old slot.
3. Once every supported machine has run it, sign with the new key only, and
   replace `RELEASE_PCR_KEY`. A machine that missed it asks for its recovery
   key once, then enrolls the TPM again.

**The Secure Boot key**, planned:

1. Generate a new `release-secureboot.key` and `release-secureboot.crt`.
2. Release a build, still signed with the old key, that queues the new
   certificate with `mokutil --import`. Shim's MOK manager asks the person to
   confirm it at the next boot, as at installation.
3. Shim measures the certificate that verified systemd-boot into PCR 7, so
   the first boot signed with the new key no longer matches the TPM slot. The
   same release must enroll a slot for the new PCR 7 value, predicted with
   `systemd-pcrlock`, or that boot asks for the recovery key.
4. Once every supported machine has enrolled the new certificate, sign with
   the new key, replace `RELEASE_SECUREBOOT_KEY`, and queue removal of the old
   certificate (`mokutil --delete`).

**After a Secure Boot key leak**, no one can revoke it remotely: every MOK
change needs the person at the machine. Stop using the key, then follow the
steps above, and also queue the old certificate in shim's deny list
(`mokutil --mokx --import`). Until the person confirms that, the machine
boots anything signed with the leaked key. This is why the keys stay off
runners as much as possible and have an offline backup.

## Supply Chain

Packages come from Fedora, with one accepted exception: Fedora has no
Hyprland, so Hyprland, its dialogs, hypridle, xdg-desktop-portal-hyprland, and
Quickshell come from the third-party
[sdegler/hyprland](https://copr.fedorainfracloud.org/coprs/sdegler/hyprland/)
COPR ([image/hyprland.repo](https://github.com/shapebit-software/os/blob/main/image/hyprland.repo)).

**Risk.** One person controls that repository, and its package scripts run as
root while the image builds. Nothing limits it to those packages: a newer
version of any Fedora package in it would be installed instead. Anything it
ships ends up in the signed image. The development container and CI's checks
enable it too.

**What limits it.** Packages are checked against the COPR's signing key. The
repository is mounted only while the image builds and is not left in the
image, so installed systems never fetch from it. The source RPMs of every
release are kept with its sources.

**Plan.** Drop the COPR as soon as Fedora ships Hyprland: remove
`hyprland.repo` and the COPR from `distrobox.ini`, and install from Fedora.
Until then, this stays a known supply-chain risk.
