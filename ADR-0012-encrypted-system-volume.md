# ADR-0012: TPM-Unlocked Encrypted System Volume

**Status:** Accepted

**Date:** 2026-08-05

## Context

ShapeBit OS must protect machine configuration, service state, administrator
data, and the bootc deployment at rest without adding a routine password prompt
before the user login screen.

Per-user encrypted homes do not protect `/usr`, `/etc`, `/var`, `/root`, or
disk-backed swap. Those paths are required before a human user logs in and
therefore cannot be unlocked with one user's password.

## Decision

- The bootc physical root is stored in a system LUKS2 volume.
- The encrypted system volume covers `/usr`, `/etc`, `/var`, `/root`, and the
  backing files for inactive per-user home containers.
- Supported production hardware must provide TPM2.
- Normal boot unlocks the system volume automatically with a TPM2-enrolled key
  bound to the verified boot state.
- Every device receives a high-entropy recovery key for TPM failure, firmware
  changes, motherboard replacement, and repair workflows.
- Normal startup does not request the device recovery key or another system
  passphrase.
- The ESP and boot assets required by UEFI remain unencrypted. Their integrity
  and authorization are governed by ADR-0013.
- Encryption is not a substitute for system integrity. OCI signatures, Secure
  Boot, signed UKIs, and deployment-integrity mechanisms remain required.

Per-user LUKS2 homes remain a second encryption layer governed by
[ADR-0011](ADR-0011-per-user-encrypted-homes.md). TPM activation of the system
volume does not activate any user's home.

## Swap

- Zram is the default swap mechanism and writes no swap contents to persistent
  storage.
- Any disk-backed swap must be encrypted.
- Disk swap without hibernation may use a fresh random key on every boot or
  reside inside the encrypted system volume.
- Hibernation requires a persistent encrypted resume area that can be unlocked
  in the initramfs. It cannot use a per-boot random key.
- Hibernation remains outside the first public release until encrypted resume,
  deployment compatibility, failed-resume cleanup, and lock-screen behavior
  pass end-to-end tests.

## Consequences

- A stolen powered-off disk does not expose system or user data.
- The normal user experience still contains only the login password prompt.
- TPM policy and recovery must be updated and tested across firmware, UKI,
  kernel, bootloader, and Secure Boot changes.
- Hardware without TPM2 cannot provide this normal-boot model and is not
  production-supported unless a later ADR defines an equivalent mechanism.
- Development VMs may use explicitly marked test keys but cannot be treated as
  evidence of production security.

Boot-chain trust, update-compatible TPM2 authorization, key custody, rotation,
and revocation are specified by
[ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md).

## Boundaries

This ADR requires encryption, automatic verified TPM2 unlock, and an independent
device recovery key. It does not select the filesystem inside the volume or the
PCR and signing policy used to authorize TPM2 unlock.

The outer system volume may contain inactive per-user home-container files. The
device recovery key unlocks only the outer system volume and never substitutes
for a user's credential or home recovery key.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md) selects the system
  filesystem.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) defines per-user encryption.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) defines verified boot and
  TPM2 authorization.
