# ADR-0003: Btrfs for Persistent System State

**Status:** Proposed
**Date:** 2026-08-04

## Context

ShapeBit OS needs logical separation, checksums, snapshots, and space management
for persistent system state. Encryption is a separate system-volume decision.

## Decision

The prototype uses Btrfs inside the system LUKS2 volume:

```text
LUKS2
└── Btrfs
    ├── @root
    ├── @var
    ├── @snapshots
    └── @recovery-data
```

Human home directories are not a shared `@home` subvolume. Each human user has
an independently encrypted LUKS2 home managed by `systemd-homed`, as decided in
[ADR-0011](ADR-0011-per-user-encrypted-homes.md). The base system/deployment
remains managed by bootc. The exact bootc deployment layout is not a Btrfs
subvolume contract owned by this ADR.

Inactive `systemd-homed` container files are stored under persistent system
state, initially `/var/lib/systemd/home/`. They receive physical-disk protection
from the outer system LUKS2 volume but retain their own per-user encryption.

The filesystem inside each user's home container remains an open choice and is
not selected by this ADR.

## Rationale

- encryption of persistent system state;
- subvolumes without rigid space partitioning;
- checksums;
- selective snapshots;
- compression;
- future send/receive capability.

## Risks

- more complex recovery;
- behavior when full;
- need for power-failure testing;
- snapshots can obscure actual space usage.

## Validation plan

- low-space tests;
- simulated power loss;
- scrub and recovery;
- snapshot/restore of system state;
- independent activation and recovery of multiple encrypted user homes;
- tests on several NVMe/SATA disks.

## Alternative

LUKS2 + ext4/XFS if Btrfs testing does not meet the M7 criteria.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines path ownership.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) defines per-user homes.
- [ADR-0012](ADR-0012-encrypted-system-volume.md) defines the outer encrypted
  system volume.
