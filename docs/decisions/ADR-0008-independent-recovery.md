# ADR-0008: Independent Recovery Environment

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-07

## Context

The previous deployment may be insufficient when a failure affects the bootloader, storage, encryption, or shared data.

## Decision

ShapeBit OS will provide a separate, minimal, independently versioned recovery image.

Recovery is outside normal deployment rotation and does not count as the
previous accepted deployment. It uses the same Secure Boot trust requirements
as the main system but has a distinct release profile and update lifecycle.

The initial recovery environment is a self-contained signed UKI stored on the
EFI System Partition. It must start without mounting the system LUKS2 volume or
its Btrfs filesystem and must contain no user secrets. The same signed recovery
environment is distributable as external USB recovery media. A separate
recovery partition is deferred unless the environment can no longer fit safely
on the ESP.

The ESP keeps two rotating recovery slots, `recovery-a` and `recovery-b`. An
update writes and verifies the inactive slot before changing selection, never
overwrites the accepted slot in place, and retains the previous recovery image
as fallback. Recovery images have candidate, accepted, and previous states in a
lifecycle independent of normal system deployments.

The initial interface is a minimal offline-first TUI usable by local keyboard
and serial console. It can import a Recovery Kit from USB or accept manual key
entry. A later graphical interface must use the same backend. Remote recovery
is deferred and may never become the only recovery path.

## Requirements

- independence from the main compositor;
- system-volume unlocking with the device recovery key;
- per-user home unlocking with that user's recovery key;
- storage diagnostics;
- deployment selection;
- reinstallation of a known image;
- data export;
- device erase with and without reinstallation.

The environment also exposes both erase outcomes defined by ADR-0005 and the
ability to retry a trial deployment, boot the previous accepted deployment
once, abandon the pending update, and inspect its health report.

Recovery mounts data read-only by default. Unlocking the system volume requires
the device recovery key when normal TPM2 authorization is unavailable.
Unlocking a user's home additionally requires that user's credential or recovery
key; the device recovery key never unlocks a per-user home.

## Consequences

Higher maintenance and storage costs, but a significantly better ability to repair the device.

## Boundaries

This ADR defines the independent environment. ADR-0005 defines the meaning and
authorization of rollback, repair, system reset, user removal, and device
erase. ADR-0007 defines automatic deployment rollback.

## Related decisions

- [ADR-0005](ADR-0005-recovery-operation-semantics.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
