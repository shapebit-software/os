# ADR-0005: Separate Rollback, Backup, and Reset Operations

**Status:** Proposed
**Date:** 2026-08-04

## Context

System rollback, data restoration, and device reset solve three different problems. Combining them creates a risk of data loss.

## Decision

- rollback changes only the system deployment;
- backup protects user data and selected settings;
- system reset restores the system and clears host configuration while
  preserving human accounts and their encrypted home containers;
- full factory reset also removes user accounts and data;
- a filesystem snapshot is not considered the sole backup.

System reset may preserve user accounts only by preserving their independently
encrypted `systemd-homed` containers and account metadata. Full reset destroys
both device state and all user-home containers. Neither operation silently
changes the meaning of deployment rollback.

## Consequences

The recovery interface must clearly present the three separate operations and their effects.

## Related decisions

- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) owns deployment rollback.
- [ADR-0008](ADR-0008-independent-recovery.md) owns the recovery environment.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) owns user-home encryption.
