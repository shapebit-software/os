# 09. Security Model

**Status:** Proposed

**Last updated:** 2026-08-06

**Related ADRs:** ADR-0011, ADR-0012, ADR-0013

## Goals

- ensure image authenticity;
- protect data after device theft;
- limit the impact of a malicious application;
- restrict system-service capabilities;
- provide secure recovery.

## Layers

1. UEFI Secure Boot.
2. Signed systemd-boot and Unified Kernel Images.
3. Signed, sealed bootc deployment with required fs-verity verification.
4. Signed OCI release metadata and immutable image digest.
5. SELinux enforcing mode.
6. Flatpak sandboxing.
7. Permission portals.
8. systemd unit hardening.
9. Per-user LUKS2 homes activated through PAM and `systemd-homed`.
10. A TPM2-unlocked LUKS2 system volume for the physical root.
11. A device recovery key independent of TPM2.
12. Signed repositories and registries.

## Threat model

At minimum, describe:

- registry compromise;
- signing-key theft;
- a malicious Flatpak;
- a malicious USB device;
- physical theft of the computer;
- a defective update;
- privilege escalation through a system service;
- lock-screen bypass;
- login-screen or PAM credential capture;
- access to an inactive user's encrypted home;
- boot-chain modification;
- unauthorized TPM unsealing after boot-chain modification;
- plaintext memory remnants in disk-backed swap or hibernation images;
- loss of access to encrypted data.

## Keys

Developer, testing, and production keys must be separate. The stable key must not be available to ordinary CI without additional controls.

Every human user receives a separate home recovery key. ShapeBit does not
escrow user passwords or recovery keys. Authentication components must never
write passwords, recovery keys, or derived encryption keys to logs.

Every device also receives a separate high-entropy system-volume recovery key.
It is shown to the owner during provisioning and is not escrowed by ShapeBit.
The TPM2 enrollment must be bound to an update-compatible verified-boot policy;
TPM possession without an accepted boot state must not release the volume key.

The initial device owner receives the device recovery key and their home
recovery key as one logical ShapeBit Recovery Kit. This is packaging, not a
cryptographic relationship: the keys remain independently generated, enrolled,
rotated, and revoked, and neither key may derive the other. The device recovery
key must not unlock any per-user home. An additional user receives only the
recovery key for that user's home and never receives the device recovery key
implicitly.

Boot trust follows [ADR-0013](../decisions/ADR-0013-boot-trust-and-tpm-policy.md):
PCR 7 binds the TPM2 keyslot to Secure Boot state, while signed PCR 11 policies
authorize the current, pending, and retained rollback UKIs. Boot signing, PCR
policy signing, OCI release signing, firmware administration, and per-device
recovery use separate keys.

Production private keys must remain in controlled signing infrastructure and
must not appear in the repository, image, installed ESP, or general CI jobs.
