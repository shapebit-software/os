# ADR-0003: LUKS2 + Btrfs for Persistent Data

**Status:** Proposed  
**Date:** 2026-08-04

## Context

ShapeBit OS needs encryption, logical data separation, snapshots, and space management.

## Decision

The prototype uses:

```text
LUKS2
└── Btrfs
    ├── @var
    ├── @home
    ├── @snapshots
    └── @recovery-data
```

The base system/deployment remains managed by bootc.

## Rationale

- persistent-data encryption;
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
- snapshot/restore;
- tests on several NVMe/SATA disks.

## Alternative

LUKS2 + ext4/XFS if Btrfs testing does not meet the M7 criteria.
