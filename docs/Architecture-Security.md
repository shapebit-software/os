# Security

This page describes how the OS protects the device and its data.

## Disk Encryption

Every machine's volume is encrypted with **LUKS2**.

On a normal boot, the volume unlocks itself automatically using the
device's **TPM2** chip — no password needed. Every device also has an
independent **recovery key**, kept separately, that can unlock the
volume if the TPM path ever fails.

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

If the TPM path fails, the recovery key is required; see [Recovery](Architecture-Recovery.md).
