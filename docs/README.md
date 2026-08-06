# ShapeBit OS documentation

This directory is the canonical source for ShapeBit OS product and system
design. Implementation-specific commands belong in the README of the component
that implements them.

## Reading order

1. [Product vision](architecture/01-product-vision.md)
2. [System architecture](architecture/02-system-architecture.md)
3. [Project status](roadmap/PROJECT-STATUS.md)
4. [First working prototype](architecture/14-first-prototype.md)

## Architecture

| Document | Scope |
|---|---|
| [01. Product vision](architecture/01-product-vision.md) | audience, promise, and MVP criteria |
| [02. System architecture](architecture/02-system-architecture.md) | system layers and responsibility boundaries |
| [03. Image and build model](architecture/03-image-and-build-model.md) | bootc image, packages, and composition |
| [04. Filesystem and persistent state](architecture/04-filesystem-and-state.md) | filesystem ownership, storage, and migrations |
| [05. Updates, deployments, and recovery](architecture/05-updates-and-recovery.md) | updates, rollback, acceptance, and recovery |
| [06. Release channels](architecture/06-release-channels.md) | channel promotion and staged rollout |
| [07. Application model](architecture/07-application-model.md) | Flatpak, containers, and host extensions |
| [08. Development workflow](architecture/08-development-workflow.md) | local, integration, and release loops |
| [09. Security model](architecture/09-security-model.md) | boot trust, encryption, sandboxing, and keys |
| [10. Desktop platform](architecture/10-desktop-platform.md) | compositor, shell, portals, and platform APIs |
| [11. Installer and hardware](architecture/11-installer-and-hardware.md) | installer boundaries and installation target |
| [12. CI/CD and testing](architecture/12-ci-cd-and-testing.md) | pipeline, validation, and publishing |
| [13. Roadmap](architecture/13-roadmap.md) | long-term product milestones |
| [14. First working prototype](architecture/14-first-prototype.md) | near-term implementation sequence |

## Decisions

Architecture decision records (ADRs) are the authority for decisions. An
architecture document may explain a decision in more detail, but should link to
the corresponding ADR instead of redefining its status.

- [ADR-0001: Fedora + bootc as the system base](decisions/ADR-0001-fedora-bootc.md)
- [ADR-0002: Filesystem ownership boundaries](decisions/ADR-0002-filesystem-ownership.md)
- [ADR-0003: LUKS2 + Btrfs for persistent data](decisions/ADR-0003-persistent-storage-btrfs-luks.md)
- [ADR-0004: Data migrations independent of image rollback](decisions/ADR-0004-data-migrations-and-rollback.md)
- [ADR-0005: Separate rollback, backup, and factory reset](decisions/ADR-0005-reset-backup-and-home.md)
- [ADR-0006: OCI digest as the release unit](decisions/ADR-0006-update-unit-oci-digest.md)
- [ADR-0007: Trial boot and explicit deployment acceptance](decisions/ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0008: Independent recovery environment](decisions/ADR-0008-independent-recovery.md)
- [ADR-0009: Staged stable rollout](decisions/ADR-0009-staged-rollout.md)
- [ADR-0010: Dioxus as the installer frontend](decisions/ADR-0010-dioxus-installer.md)
- [ADR-0011: Per-user encrypted homes](decisions/ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012: TPM-unlocked encrypted system volume](decisions/ADR-0012-encrypted-system-volume.md)
- [ADR-0013: Boot trust and TPM2 unlock policy](decisions/ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR template](decisions/ADR-TEMPLATE.md)

ADR statuses:

- **Draft** — incomplete decision record.
- **Proposed** — under review and not binding.
- **Accepted** — current binding decision.
- **Deprecated** — no longer recommended.
- **Superseded** — replaced by another ADR.

## Delivery documents

- [Project status](roadmap/PROJECT-STATUS.md) records what exists now and what
  has been verified.
- [Roadmap](architecture/13-roadmap.md) records long-term milestones.
- [First working prototype](architecture/14-first-prototype.md) is the active
  near-term implementation plan.
- [Persistent-state component checklist](checklists/persistent-state-component.md)
- [Update candidate checklist](checklists/update-release-candidate.md)
