# Architecture Decision Records

Architecture Decision Records (ADRs) are the authoritative record of durable
ShapeBit OS design choices. The system design summarizes accepted decisions and
tracks proposed work, but it does not override an ADR.

## Status model

- **Proposed** — a candidate design that may still change.
- **Accepted** — the current binding decision.
- **Superseded** — replaced by another ADR, which must be linked explicitly.

Changing an accepted decision requires a new ADR that supersedes it. Validation
criteria do not make a proposed decision accepted automatically; acceptance is
an explicit review action.

## Decision map

| ADR | Status | Owns |
|---|---|---|
| [ADR-0001](ADR-0001-fedora-bootc.md) | Accepted | Fedora bootc system base |
| [ADR-0002](ADR-0002-filesystem-ownership.md) | Proposed | ownership and mutability of filesystem paths |
| [ADR-0003](ADR-0003-btrfs-system-state.md) | Accepted | filesystem inside the system LUKS2 volume |
| [ADR-0004](ADR-0004-data-migrations-and-rollback.md) | Accepted | persistent-data schema compatibility and migrations |
| [ADR-0005](ADR-0005-recovery-operation-semantics.md) | Accepted | semantic difference between rollback, backup, and reset |
| [ADR-0006](ADR-0006-signed-release-manifest.md) | Proposed | immutable release identity and signed release manifest |
| [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) | Accepted | deployment states, trial boot, acceptance, and rollback selection |
| [ADR-0008](ADR-0008-independent-recovery.md) | Accepted | independent recovery environment |
| [ADR-0009](ADR-0009-staged-rollout.md) | Proposed | server-side stable-channel rollout |
| [ADR-0010](ADR-0010-dioxus-installer.md) | Accepted | Dioxus installer frontend and privilege boundary |
| [ADR-0011](ADR-0011-per-user-encrypted-homes.md) | Accepted | human-user authentication and encrypted homes |
| [ADR-0012](ADR-0012-encrypted-system-volume.md) | Accepted | system-volume encryption and recovery key |
| [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) | Proposed | verified boot and TPM2 authorization policy |
| [ADR-0014](ADR-0014-platform-and-hardware-validation.md) | Accepted | platform scope, hardware evidence, and release hardware gates |
| [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md) | Accepted | Microsoft-signed ShapeBit shim and trust-domain separation |
| [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md) | Accepted | initial disk ownership, recovery placement, and home capacity profile |

## Boundary rules

- ADR-0003 selects the filesystem layout; ADR-0012 requires the outer system
  volume to be encrypted.
- ADR-0004 owns data migrations; ADR-0007 only consumes their success or failure
  when accepting a deployment.
- ADR-0005 defines user-visible recovery operations; ADR-0008 defines the
  independent environment that can perform them.
- ADR-0006 identifies a release; ADR-0009 controls how an accepted release is
  offered to device cohorts.
- ADR-0011 protects each human user's home independently; ADR-0012 protects
  device state and the inactive home-container files at the physical-disk layer.
- ADR-0012 requires verified TPM2 unlock; ADR-0013 defines the boot-chain and
  PCR policy that may authorize that unlock.
- ADR-0014 defines where evidence is required; ADR-0015 defines the
  firmware-to-shim compatibility boundary; ADR-0013 defines authorization after
  that boundary.
- ADR-0016 selects the initial installation profile; ADR-0003 and ADR-0008 own
  the detailed outer filesystem and recovery lifecycles.
