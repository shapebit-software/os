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
