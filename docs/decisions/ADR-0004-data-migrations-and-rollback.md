# ADR-0004: Persistent State Compatibility Without Automatic Migrations

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-07

## Context

A bootc rollback restores the base system while persistent `/etc`, `/var`, and
human homes remain. A general reversible-migration framework would require
schema classification, bidirectional transforms, transaction recovery, rollback
barriers, and bridge releases before ShapeBit has concrete migrations that need
those mechanisms.

## Decision

- Stable updates do not perform incompatible automatic migrations of persistent
  host data.
- Persistent host paths have exactly two lifecycle classes:
  - `preserved`: the data remains readable and safe for both N and N-1 during
    the complete rollback window;
  - `disposable`: the data may be deleted and recreated without losing user
    data or required device configuration.
- An undeclared persistent path blocks stable release.
- A host service is eligible only when it is stateless, owns only `disposable`
  state, or has tested N/N-1 compatibility for all `preserved` state.
- Additive changes are permitted only when the previous release safely ignores
  and preserves them.
- Caches and indexes may be rebuilt; durable data may not be silently
  discarded or transformed into an N-1-incompatible representation.
- Flatpak application data and formats remain the responsibility of each
  application and are outside the host rollback contract.

Stable validation exercises the following cycle with representative state:

```text
release N -> create state -> update to N+1 -> use N+1 -> roll back to N
```

After rollback, all `preserved` state must remain usable and every `disposable`
path must be safe to recreate. A component that cannot meet this contract is
pinned, excluded from the host, redesigned, or receives a compatible backport.
The incompatible feature does not ship in stable.

The initial system has no general migration engine, reverse migrations,
rollback barrier, or mandatory bridge-release mechanism. A concrete future need
for incompatible durable-state evolution requires a new ADR based on that
actual case.

This ADR owns persistent-data compatibility. It does not define boot-attempt
counting or deployment selection, which belong to ADR-0007.

## Consequences

This keeps the update and rollback mechanism small and testable, and encourages
a minimal host. It may delay features, require version pinning, or require
security-fix backports when an upstream component changes persistent formats.
Snapshots may later assist recovery, but they are not part of the rollback
correctness guarantee.

## Re-evaluation criteria

- A required host component cannot receive a critical security fix while
  retaining the N/N-1 contract.
- A concrete product feature requires an incompatible persistent-data change.
- The cost of compatible backports exceeds the verified complexity of a scoped
  migration design.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines persistent paths.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines deployment
  acceptance and rollback selection.
