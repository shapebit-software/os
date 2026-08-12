# ADR-0028: Capacity and Low-Space Policy

**Status:** Accepted

**Date:** 2026-08-09

## Context

ADR-0016 establishes dynamically sized encrypted homes, a shared burst pool,
and a protected system reserve. ShapeBit needs exact accounting rules so that
ordinary home growth cannot consume the space required for updates, rollback,
recovery, and basic system operation.

## Decision

### Protected system reserve

The protected reserve is free outer-filesystem capacity that may be consumed
only by the system purpose for which it was reserved. It is not a partition and
is never offered as home capacity.

ShapeBit calculates the reserve in GiB as:

```text
reserve = max(30 GiB, emergency + transactions + update + metadata + migration)
```

The components are:

- `emergency`: 8 GiB for recovery from a low-space condition;
- `transactions`: 4 GiB for system transactions, bounded logs, and temporary
  service state;
- `update`: the greater of 12 GiB and the signed release's declared staging
  requirement;
- `metadata`: 2% of outer-filesystem capacity, clamped to 4--16 GiB; and
- `migration`: additional workspace explicitly declared by a release, zero
  when no such operation exists.

The installed current, previous accepted, pending, and trial deployments and
recovery assets are actual protected allocations. Their occupied bytes are
deducted before home capacity is offered and are not counted a second time in
the free-space reserve. Filesystem accounting must use allocated physical space,
not apparent sparse-file size.

An approved system operation may consume its own reserve component and must
release unused workspace when it completes. Home growth cannot consume any
reserve component.

### Home guarantees and limits

Every human home has a 16 GiB guaranteed minimum. This is an admission-control
promise, not eager physical preallocation. The initial product does not allow
the guarantee to be reduced.

Before permitting creation of a user or growth of a home beyond its current
allocation, ShapeBit protects:

- the system reserve;
- the unused part of every other user's 16 GiB guarantee; and
- all existing allocated user data.

A new account is rejected when its complete 16 GiB guarantee cannot be made
without violating those protections. Existing allocated data is never shrunk,
reclaimed, or deleted to admit another account.

Capacity beyond the guarantees is one opportunistic shared burst pool. Its
default allocation follows actual writes rather than fixed equal shares. A user
may consume all currently admissible burst capacity but cannot consume another
home's unused guarantee or the system reserve. Previously written burst data is
not reclaimed when another user needs space.

The default per-user limit is `unlimited`, meaning all capacity admissible under
these rules, not all physical free space. An administrator may assign a hard
per-user limit, but not below 16 GiB or the home's current allocated use,
whichever is greater. Removing a limit restores access to the shared pool; it
does not promise additional capacity.

### Low-space states

ShapeBit calculates user-available headroom after the system reserve and all
unused home guarantees have been protected. It exposes three states:

- **low** when headroom is below the greater of 16 GiB and 10% of total home
  pool capacity;
- **critical** when headroom is below 8 GiB; and
- **exhausted** when no admissible burst capacity remains.

At exhaustion, ShapeBit denies further allocation above the applicable
guarantee or hard limit. It does not delete or truncate existing data. An
application can still fail to save, so the UI must not promise preservation of
unsaved work.

### Cleanup and warnings

Entering the critical state triggers bounded automatic cleanup of system-owned
data explicitly classified as rebuildable. Examples include abandoned update
download fragments, expired system temporary files, logs beyond their owning
retention policy, and caches with a tested rebuild path.

Automatic cleanup never removes:

- user files, application data, or application caches;
- Flatpaks or AppImages;
- a current, previous accepted, pending, or trial deployment;
- recovery assets or Recovery Kit material;
- transaction-critical state; or
- diagnostics retained for an active failure.

The low state produces one notification and a persistent panel indicator. The
critical state may remind at most once per day. Every user sees the general
state and their own use. Administrators additionally see all home allocations,
the protected reserve, and categorized system use. The lock screen exposes only
a generic system warning without user identities or capacity figures.

Notifications open storage management but do not authorize deletion. Except
for the bounded system cleanup above, deletion requires an explicit user
action.

### Insufficient space for a system operation

Before downloading or staging an update, ShapeBit checks the signed declared
space requirement. If the operation cannot complete while preserving the
reserve, existing home data, and unused guarantees, it does not start or safely
pauses before exhausting admissible space. It blocks new accounts and limit
increases while the shortage remains and tells an administrator how much space
is missing and which safe actions are available.

The rule also applies to security updates. Urgency does not authorize ShapeBit
to delete user data, revoke occupied capacity, or breach the reserve.

## Consequences

- A full home pool does not consume the minimum capacity required for system
  maintenance.
- A fixed 30 GiB floor remains predictable on ordinary laptops, while declared
  large operations and filesystem metadata can raise it.
- A 16 GiB guarantee is useful without eagerly consuming disk space.
- Opportunistic bursting is simple and space-efficient, but an early heavy user
  can consume most capacity beyond other users' guarantees.
- Lack of space may delay even a security update until an administrator frees
  capacity.
- Correct sparse-file, reflink, and Btrfs physical-allocation accounting is a
  required validation target.

## Boundaries

This ADR owns numerical reserve inputs, home guarantees and limits, shared-burst
admission, low-space states, warnings, and safe cleanup boundaries. ADR-0016
owns the installation storage profile and dynamic-home model. ADR-0003 owns the
outer Btrfs structure and corruption policy. ADR-0029 owns snapshot behavior;
unmanaged snapshots count as real allocated capacity under this policy.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0029](ADR-0029-no-managed-snapshots.md)
