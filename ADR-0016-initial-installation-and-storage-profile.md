# ADR-0016: Initial Installation and Storage Profile

**Status:** Accepted
**Date:** 2026-08-06
**Last updated:** 2026-08-15

## Context

The initial installer needs one storage profile that can be validated safely,
recovered independently, and tested consistently. Alongside installation,
manual partitioning, and several home-allocation modes would multiply
destructive and low-space failure cases before the core lifecycle is proven.

## Decision

### Disk ownership

- The initial installer takes exclusive ownership of one explicitly selected
  physical disk.
- It does not shrink existing partitions, install alongside another system, or
  offer manual partitioning.
- Installation erases the selected disk after strict identity validation and
  destructive-action confirmation.
- Other physical disks remain untouched.
- Eligible external disks are permitted under the identity and additional
  confirmation rules in ADR-0038; the running installer medium is never a
  target.
- Same-disk dual boot is deferred even though the Microsoft-signed shim model
  preserves a future compatibility path.

### Initial layout

```text
GPT
├── EFI System Partition
│   ├── Microsoft-signed ShapeBit shim
│   ├── normal signed boot artifacts
│   └── minimal signed recovery UKI
└── system LUKS2
    └── Btrfs persistent system state
        └── systemd-homed LUKS2 container files
            └── Btrfs per-user filesystem
```

The recovery UKI is self-contained, independently versioned, outside normal
deployment rotation, and able to start without the system LUKS2 or Btrfs. It
contains no user secrets. The same signed recovery environment is distributable
as external USB recovery media.

### Home capacity policy

- Human users use the independent LUKS2 containers defined by ADR-0011.
- Btrfs is the filesystem inside every human-user LUKS2 home.
- Homes share a dynamically managed capacity pool rather than fixed partitions
  or permanently preallocated sizes.
- Every home has a guaranteed minimum plus access to a shared burst pool.
- Burst capacity follows actual use by default; the device owner may set
  explicit limits as defined by ADR-0028.
- Creating a new user is allowed only when the system can guarantee that
  user's minimum without revoking space already used by another home.
- The outer filesystem protects separate emergency, update/trial-rollback,
  service-state, and recovery reserves from ordinary home growth.
- An unlimited user setting means access to the available home pool, not to all
  physical free space.
- The system must not promise aggregate guaranteed home capacity greater than
  physical capacity.

The protected reserve is calculated dynamically rather than as one fixed
percentage or fixed number of GiB. Its inputs include an emergency floor,
transaction and log space, a pending deployment, the retained rollback
baseline until acceptance, migration workspace, and Btrfs metadata
requirements.

Automatic low-space cleanup may remove only data explicitly declared
rebuildable. It never removes user data or homes, the current deployment, a
pending or trial deployment, its required rollback baseline, recovery assets,
or transaction-critical state. An old deployment cached after acceptance is
not protected by this rollback rule.

ADR-0028 defines the numerical home minimum, reserve formula, quotas, burst
admission, cleanup, and warning thresholds. ADR-0029 defines that ShapeBit does
not create managed snapshots. A snapshot of an active outer `.home` image is
not considered a valid backup of the inner filesystem.

## Rationale

Exclusive disk ownership gives the installer one safe and testable destructive
contract. A recovery UKI on the ESP remains bootable after system-filesystem
damage. Btrfs inside each home provides checksums, compression before
encryption, and online resizing needed by a dynamic shared pool.

## Positive consequences

- The first installer avoids filesystem shrinking and ambiguous layouts.
- Recovery does not depend on mounting the damaged system volume.
- Home capacity can adapt to actual use without rigid partitioning.
- The same recovery image can serve local and external recovery paths.

## Negative consequences

- Same-disk dual boot and manual layouts are unavailable.
- Installation requires erasing a complete selected disk.
- Nested Btrfs and dynamically sized LUKS home images require careful low-space
  and fragmentation testing.
- An attacker may delete an unencrypted ESP recovery image and cause denial of
  service, although modification cannot create a trusted recovery image.

## Boundaries

This ADR owns the initial installer disk-ownership contract, recovery-image
placement, per-user filesystem choice, and dynamic home-pool model. ADR-0003
owns the detailed outer Btrfs subvolume layout. ADR-0008 owns recovery
operations and lifecycle. ADR-0028 owns capacity accounting and low-space
behavior. ADR-0029 owns snapshot policy.

## Re-evaluation criteria

- Same-disk dual boot becomes an accepted product requirement.
- The minimal recovery environment no longer fits safely on the ESP.
- Btrfs-in-LUKS homes fail low-space, recovery, or performance validation.
- A fixed-allocation or separate-home-partition product profile is introduced.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0008](ADR-0008-independent-recovery.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0028](ADR-0028-capacity-and-low-space-policy.md)
- [ADR-0029](ADR-0029-no-managed-snapshots.md)
- [ADR-0038](ADR-0038-installer-disk-identity-and-confirmation.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
