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
| [ADR-0004](ADR-0004-data-migrations-and-rollback.md) | Accepted | persistent-state classes and N/N-1 compatibility without automatic migrations |
| [ADR-0005](ADR-0005-recovery-operation-semantics.md) | Accepted | semantic difference between rollback, backup, and reset |
| [ADR-0006](ADR-0006-signed-release-manifest.md) | Proposed | immutable release identity and signed release manifest |
| [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) | Accepted | deployment states, trial boot, acceptance, and rollback selection |
| [ADR-0008](ADR-0008-independent-recovery.md) | Accepted | independent recovery environment |
| [ADR-0009](ADR-0009-staged-rollout.md) | Accepted | staged rollout, telemetry, withdrawal, and revocation |
| [ADR-0010](ADR-0010-dioxus-installer.md) | Accepted | Dioxus installer frontend and privilege boundary |
| [ADR-0011](ADR-0011-per-user-encrypted-homes.md) | Accepted | human-user authentication and encrypted homes |
| [ADR-0012](ADR-0012-encrypted-system-volume.md) | Accepted | system-volume encryption and recovery key |
| [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) | Proposed | verified boot and TPM2 authorization policy |
| [ADR-0014](ADR-0014-platform-and-hardware-validation.md) | Accepted | platform scope, hardware evidence, and release hardware gates |
| [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md) | Accepted | Microsoft-signed ShapeBit shim and trust-domain separation |
| [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md) | Accepted | initial disk ownership, recovery placement, and home capacity profile |
| [ADR-0017](ADR-0017-application-distribution-and-appimage.md) | Superseded | replaced by ADR-0023 |
| [ADR-0018](ADR-0018-desktop-session-and-authorization.md) | Accepted | desktop process isolation, session failure, authorization, developer mode, and SSH |
| [ADR-0019](ADR-0019-display-power-and-thermal-policy.md) | Accepted | display, HDR, VRR, suspend, power, battery, and thermal policy |
| [ADR-0020](ADR-0020-media-privacy-and-notifications.md) | Accepted | media routing, capture consent, remote input, and notification privacy |
| [ADR-0021](ADR-0021-network-ownership-and-privacy.md) | Accepted | network ownership, VPN, DNS, firewall, SSH exposure, and discovery |
| [ADR-0022](ADR-0022-inbound-file-sharing.md) | Accepted | SFTP and SMB scope, credentials, exposure, lifecycle, and privacy |
| [ADR-0023](ADR-0023-application-platform-and-system-set.md) | Accepted | system applications, Flatpak integrations, browsers, AppImage, and Distrobox |
| [ADR-0024](ADR-0024-application-recommendations.md) | Accepted | recommendation governance, criteria, signed distribution, and presentation |
| [ADR-0025](ADR-0025-enterprise-network-authentication.md) | Accepted | enterprise Wi-Fi, VPN protocols, credentials, import, and server identity |
| [ADR-0026](ADR-0026-boot-health-contract.md) | Accepted | boot-health checks, timeouts, observation, and failure transitions |
| [ADR-0027](ADR-0027-staged-restart-ux.md) | Accepted | staged-update indicators, reminders, and user-controlled restart behavior |
| [ADR-0028](ADR-0028-capacity-and-low-space-policy.md) | Accepted | system reserve, home guarantees, quotas, low-space behavior, and cleanup |
| [ADR-0029](ADR-0029-no-managed-snapshots.md) | Accepted | absence of managed snapshots and treatment of unmanaged snapshots |
| [ADR-0030](ADR-0030-platform-service-api-contract.md) | Accepted | internal platform services, API versions, authorization, jobs, errors, and lifecycle |
| [ADR-0031](ADR-0031-diagnostic-reports-and-consent.md) | Accepted | diagnostic envelope, data handling, global consent, retention, and export |
| [ADR-0032](ADR-0032-host-customization-and-integrity-status.md) | Accepted | configuration layers, customization detection, support effects, integrity response, and restoration |
| [ADR-0033](ADR-0033-simple-test-evidence.md) | Accepted | simple QEMU and physical test reports, pass rules, and community minimum |
| [ADR-0034](ADR-0034-release-cadence-and-candidate-aging.md) | Accepted | target stable cadence, candidate aging, and emergency security timing |
| [ADR-0035](ADR-0035-minimal-installer-protocol.md) | Accepted | local installer transport, minimal plan, capabilities, Wi-Fi, events, and errors |

## Boundary rules

- ADR-0003 selects the filesystem layout; ADR-0012 requires the outer system
  volume to be encrypted.
- ADR-0004 owns persistent-state classes and N/N-1 compatibility; ADR-0007 owns
  boot attempts, health gates, acceptance, and deployment selection.
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
- ADR-0023 owns application delivery and per-user application lifecycle;
  ADR-0011 and ADR-0016 own the encrypted-home and capacity boundaries.
- ADR-0018 owns graphical and remote session behavior; ADR-0011 remains the
  authority for PAM activation and encrypted-home lifecycle.
- ADR-0019 owns display and power policy; ADR-0014 owns the evidence required
  before those capabilities may be claimed for hardware.
- ADR-0020 owns media and notification privacy; ADR-0023 defines why direct
  microphone or camera enforcement is not guaranteed for AppImage.
- ADR-0021 owns network connectivity and exposure; ADR-0018 owns SSH
  authentication and session lifecycle.
- ADR-0022 owns inbound file-sharing behavior; ADR-0021 owns its network-profile
  and firewall boundaries, while ADR-0018 owns the underlying SSH lifecycle.
- ADR-0024 owns the curated recommendation signal; ADR-0023 owns the underlying
  application sources, installation, updates, and runtime behavior.
- ADR-0025 owns enterprise authentication and credential types; ADR-0021 owns
  network-profile ownership, activation, routing, DNS, and firewall behavior.
- ADR-0026 owns health evidence and failure transitions within a trial boot;
  ADR-0007 owns attempts, blessing, and deployment selection.
- ADR-0027 owns the user-facing wait for restart; ADR-0007 owns the staged
  deployment and what the subsequent trial boot means.
- ADR-0028 owns numerical capacity and low-space rules; ADR-0016 owns the
  installation storage profile and dynamic-home model.
- ADR-0029 owns snapshot behavior; ADR-0007 owns deployment rollback, and a
  future backup design must remain independent of both.
- ADR-0030 owns the common platform-service contract; each domain ADR owns the
  product policy performed through that contract.
- ADR-0031 owns detailed diagnostic reports; ADR-0009 owns separate minimal
  rollout telemetry.
- ADR-0032 owns writable-host customization and its support status; signed boot
  and image verification remain owned by their trust decisions.
- ADR-0033 owns the test-report format and pass criteria; ADR-0014 owns hardware
  labels and release gates.
- ADR-0034 owns release timing; ADR-0009 owns immutable promotion and rollout.
- ADR-0035 owns the ordinary installer protocol; later installer decisions own
  secrets, transaction state, disk confirmation, and Recovery Kit UX.
