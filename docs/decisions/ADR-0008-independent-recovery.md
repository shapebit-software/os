# ADR-0008: Independent Recovery Environment

**Status:** Proposed
**Date:** 2026-08-04

## Context

The previous deployment may be insufficient when a failure affects the bootloader, storage, encryption, or shared data.

## Decision

ShapeBit OS will provide a separate, minimal, independently versioned recovery image.

Recovery is outside normal deployment rotation and does not count as the
previous accepted deployment. It uses the same Secure Boot trust requirements
as the main system but has a distinct release profile and update lifecycle.

## Requirements

- independence from the main compositor;
- system-volume unlocking with the device recovery key;
- per-user home unlocking with that user's recovery key;
- storage diagnostics;
- deployment selection;
- reinstallation of a known image;
- data export;
- factory reset.

Recovery mounts data read-only by default. Unlocking the system volume requires
the device recovery key when normal TPM2 authorization is unavailable.
Unlocking a user's home additionally requires that user's credential or recovery
key; the device recovery key never unlocks a per-user home.

## Consequences

Higher maintenance and storage costs, but a significantly better ability to repair the device.

## Boundaries

This ADR defines the independent environment. ADR-0005 defines the meaning of
rollback, backup, system reset, and full reset. ADR-0007 defines automatic
deployment rollback.

## Related decisions

- [ADR-0005](ADR-0005-recovery-operation-semantics.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
