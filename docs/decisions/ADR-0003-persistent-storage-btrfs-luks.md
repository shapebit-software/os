# ADR-0003: LUKS2 + Btrfs for Persistent Data

**Status:** Proposed  
**Date:** 2026-08-04

## Context

ShapeBit OS needs encryption, logical data separation, snapshots, and space management.

## Decision

The prototype uses Btrfs for persistent system state inside LUKS2:

```text
LUKS2
└── Btrfs
    ├── @var
    ├── @snapshots
    └── @recovery-data
```

Human home directories are not a shared `@home` subvolume. Each human user has
an independently encrypted LUKS2 home managed by `systemd-homed`, as decided in
[ADR-0011](ADR-0011-per-user-encrypted-homes.md). The base system/deployment
remains managed by bootc and is protected by the system LUKS2 volume defined in
[ADR-0012](ADR-0012-encrypted-system-volume.md).

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
