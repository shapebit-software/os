# ADR-0029: No Managed Snapshots

**Status:** Accepted

**Date:** 2026-08-09

## Context

Btrfs can create cheap copy-on-write snapshots, but cheap creation does not
make retention, capacity accounting, consistency, or recovery semantics free.
ShapeBit already uses bootc deployments for system-image rollback and requires
persistent host state to remain compatible across the N/N-1 rollback window.
Each human home is also a separate active filesystem inside an encrypted
container file, which an outer snapshot cannot safely represent as a general
file-level recovery point.

The initial product needs one clear recovery model and predictable low-space
behavior more than it needs an additional checkpoint mechanism.

## Decision

### Managed scope

The initial ShapeBit release creates no managed Btrfs snapshots. This applies
to outer `@root`, `@state`, `@homes`, and `@recovery` subvolumes and to the Btrfs
filesystem inside every user home.

ShapeBit does not create scheduled snapshots, pre-update snapshots,
pre-administration snapshots, migration snapshots, or user file-history
snapshots. It exposes no ordinary Settings, Files, or recovery action for
creating or restoring them. The initial layout retains no `@snapshots`
subvolume.

Because ShapeBit owns no snapshots, it has no managed snapshot retention or
automatic snapshot-deletion schedule. A future ShapeBit feature that creates a
snapshot requires a new accepted decision defining its consistency point,
owner, capacity budget, retention, deletion, and recovery semantics.

### Relationship to rollback and backup

Bootc deployment selection and ADR-0007 trial rollback remain the only managed
system-version rollback mechanism. They do not restore persistent user or
device data and are not described as filesystem snapshots.

A snapshot is never represented as a backup. A backup must have an independently
defined export, integrity, encryption, retention, and restore contract and must
survive loss of the source disk. A snapshot of an outer active `.home` container
is not a valid backup or supported restore point for its inner filesystem.

### Unmanaged snapshots

ShapeBit does not intentionally block an administrator or developer tool from
creating a Btrfs snapshot outside the supported product interface. When it
detects such a snapshot, it:

- leaves the snapshot and its contents untouched;
- never deletes it automatically, including under low-space pressure;
- accounts for its physical allocation as unmanaged system data;
- reports its presence and capacity impact in storage diagnostics; and
- warns that it may prevent updates or other operations from meeting the
  ADR-0028 reserve contract.

ShapeBit does not accept responsibility for the snapshot's consistency,
retention, restoration, or deletion. ADR-0032 determines the resulting support
status as part of the broader host-customization policy.

## Consequences

- Initial rollback, recovery, and low-space behavior remain small and
  understandable.
- Snapshot retention cannot silently consume the protected system reserve.
- ShapeBit provides no built-in previous-version file recovery and no local
  checkpoint before administrator changes.
- Bootc rollback does not undo a harmful persistent-data change; the N/N-1
  compatibility contract remains essential.
- Externally created snapshots remain possible for development, but ShapeBit
  neither manages nor automatically removes them.

## Boundaries

This ADR owns managed snapshot scope, the absence of retention and deletion,
handling of unmanaged snapshots, and the distinction between snapshot,
deployment rollback, and backup. ADR-0003 owns the Btrfs layout. ADR-0007 owns
deployment rollback. ADR-0028 owns capacity accounting and low-space behavior.
ADR-0032 owns the support status of modified host state. A future backup design
must be recorded separately.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0004](ADR-0004-data-migrations-and-rollback.md)
- [ADR-0005](ADR-0005-recovery-operation-semantics.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0028](ADR-0028-capacity-and-low-space-policy.md)
- [ADR-0032](ADR-0032-host-customization-and-integrity-status.md)
