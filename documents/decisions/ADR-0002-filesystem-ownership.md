# ADR-0002: Filesystem Ownership Boundaries

**Status:** Proposed
**Date:** 2026-08-04
**Last updated:** 2026-08-15

## Context

An image-based system requires a clear separation between code, machine configuration, and persistent state. Without it, image rollback may conflict with local changes.

## Decision

- `/usr` and `/opt` belong to the image and are read-only during normal operation.
- `/etc` stores only device and administrator configuration.
- `/var` stores persistent service state.
- `/home` stores user data and preferences.
- `/run` and `/tmp` are ephemeral.
- vendor defaults should be placed in `/usr`, not `/etc`, when supported by the component.

This ADR defines logical ownership, not the partition table, filesystem type,
encryption topology, snapshot policy, or migration mechanism.

## Positive consequences

- predictable deployments;
- auditable changes;
- simpler image rollback;
- less configuration drift.

## Negative consequences

- some existing software will require changes;
- persistent host data must obey the forward-migration and trial-rollback
  contract;
- administrators cannot treat the host like a traditional Fedora installation.

## Review criteria

Review after the first working update + rollback in M2.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md) selects the persistent
  system filesystem and subvolume layout.
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
  defines host-state migration and compatibility before trial acceptance.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) defines human-user homes.
- [ADR-0012](ADR-0012-encrypted-system-volume.md) defines system encryption.
- [ADR-0032](ADR-0032-host-customization-and-integrity-status.md) defines
  configuration layering, customization detection, and host status.
