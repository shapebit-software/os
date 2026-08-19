# ADR-0003: Btrfs for Persistent System State

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-09

## Context

ShapeBit OS needs a small, understandable set of storage boundaries, checksums,
and shared-space management for persistent system state. Encryption is a
separate system-volume decision. Snapshot policy is deliberately not part of
this decision.

## Decision

Use Btrfs inside the system LUKS2 volume with four structural subvolumes:

```text
LUKS2
└── Btrfs
    ├── @root
    ├── @state
    ├── @homes
    └── @recovery
```

The names are lowercase, single-word structural identifiers prefixed with `@`.
`@root` holds the persistent root/configuration boundary, `@state` holds
device and service state, `@homes` holds inactive encrypted home-container
files, and `@recovery` holds only the minimal persistent recovery inventory and
state. The signed recovery UKIs themselves remain on the ESP.

Do not create one subvolume per service. A service uses normal directories
inside `@state` unless a later accepted decision establishes a concrete
lifecycle boundary. There is no `@snapshots` subvolume in the initial layout.
ADR-0029 defines that the initial product creates no managed snapshots.

Human home directories are not a shared `@home` subvolume. Each human user has
an independently encrypted LUKS2 home managed by `systemd-homed`, as decided in
[ADR-0011](ADR-0011-per-user-encrypted-homes.md). The base system/deployment
remains managed by bootc. The exact bootc deployment layout is not a Btrfs
subvolume contract owned by this ADR.

Inactive `systemd-homed` container files are stored in `@homes` and exposed at
the systemd-homed path selected by implementation. They receive physical-disk
protection from the outer system LUKS2 volume but retain their own per-user
encryption. Keeping them outside `@state` allows system reset to preserve homes
without preserving ordinary host state.

ADR-0016 selects Btrfs inside each user's LUKS2 home and a dynamic shared home
capacity pool. This ADR still owns only the outer persistent-system-state
filesystem and its detailed subvolume layout.

## Rationale

- encryption of persistent system state;
- subvolumes without rigid space partitioning;
- checksums;
- compression;
- future send/receive capability.

## Risks

- more complex recovery;
- behavior when full;
- need for power-failure testing;
- a future snapshot feature would add retention and capacity complexity.

## Corruption policy

Recovery is conservative and export-first:

- run diagnostics, scrub healthy filesystems regularly, and mount read-only
  wherever possible after suspected corruption;
- never run destructive `btrfs check --repair` automatically;
- export encrypted home containers to another physical medium before repair
  attempts whenever the source remains readable;
- prefer non-mutating recovery such as `btrfs restore` when normal mounting is
  unsafe;
- after confirmed structural corruption, prefer creating a new filesystem or
  replacing the disk instead of trusting an in-place repair;
- expose destructive expert repair only as a separate, strongly warned mode.

Scrub validates checksums and may repair data only when another valid copy
exists. ShapeBit does not present scrub as a guarantee that single-copy data can
be reconstructed.

## Validation plan

- low-space tests;
- simulated power loss;
- scrub and recovery;
- read-only diagnostics and export after simulated structural corruption;
- independent activation and recovery of multiple encrypted user homes;
- tests on several NVMe/SATA disks.

## Alternative

LUKS2 + ext4/XFS if Btrfs testing does not meet the M7 criteria.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines path ownership.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) defines per-user homes.
- [ADR-0012](ADR-0012-encrypted-system-volume.md) defines the outer encrypted
  system volume.
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md) defines the
  initial disk-ownership, recovery placement, and per-user filesystem profile.
- [ADR-0029](ADR-0029-no-managed-snapshots.md) defines the absence of managed
  snapshots in the initial product.
