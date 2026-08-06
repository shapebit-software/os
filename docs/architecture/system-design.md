# ShapeBit OS System Design

**Document type:** Living system design and delivery tracker

**Last updated:** 2026-08-06

**Current phase:** Architecture consolidation and first-prototype planning

## 1. How to use this document

This file is the single overview of ShapeBit OS architecture, current state,
and planned work. It replaces the former numbered architecture documents,
roadmap, project-status page, and temporary continuation note.

Architecture Decision Records in [`../decisions/`](../decisions/README.md) are
authoritative for durable decisions. This file summarizes them and may describe
proposed designs, but it does not silently accept or override an ADR.

Task markers have strict meanings:

- `[x]` — completed and, where relevant, supported by recorded evidence;
- `[ ]` — not completed or not yet verified;
- **Accepted** — binding architecture decision;
- **Proposed** — candidate architecture awaiting explicit review.

Documentation completion and implementation completion are tracked separately.
A design, script, or scaffold is not evidence that the system works.

## 2. Product direction

ShapeBit OS is an image-based Linux desktop operating system built on Fedora
bootc. It hides package and deployment mechanics behind a coherent product
model while preserving diagnostics and controlled developer workflows.

The initial audience is technical users, developers, and testers using
controlled x86-64 UEFI and TPM2 hardware or virtual machines. Broad arbitrary-PC
support and a polished consumer ecosystem are outside the first release.

The product must eventually provide:

- predictable boot, update, rollback, and recovery;
- a read-only image-owned operating system;
- encrypted device state and independently encrypted user homes;
- one password interaction for user authentication and home activation;
- sandboxed applications that do not modify the host;
- a custom, modular Wayland desktop;
- reproducible releases with verifiable provenance;
- useful diagnostics without collecting user content or secrets.

## 3. Current verified state

The repository coordinates documentation and two implementation submodules:

```text
os/
├── docs/
│   ├── architecture/system-design.md
│   ├── decisions/
│   └── checklists/
├── image/       # independent Git repository
└── installer/   # independent Git repository
```

Current evidence supports only the following claims:

- [x] Fedora bootc is accepted as the system base.
- [x] The `image` repository contains a console-image scaffold, build scripts,
  QEMU scripts, and container tests.
- [x] The `installer` repository documents UI, protocol, and backend boundaries.
- [x] The durable decisions have an index and explicit ownership boundaries.
- [x] The architecture and work tracker are consolidated in this document.
- [ ] A successful end-to-end container image build is recorded.
- [ ] A successful disk-image build is recorded.
- [ ] A successful UEFI boot and TTY login are recorded.
- [ ] Secure Boot, signed UKI, sealed deployment, TPM2 unlock, and recovery-key
  behavior are implemented and verified.
- [ ] The installer Rust crates exist.
- [ ] The custom desktop exists.

## 4. Decision register

See `docs/decisions/README.md`.

## 5. System context and responsibility boundaries

```text
User applications
        |
Flatpak and portals
        |
ShapeBit desktop processes
        |
Versioned D-Bus platform services
        |
systemd, logind, NetworkManager, PipeWire, SELinux
        |
ShapeBit OS bootc image
        |
bootc deployment mechanism
        |
Fedora, kernel, Mesa, firmware, hardware
```

- **Fedora** provides the kernel, Mesa, systemd, RPM infrastructure, and base
  packages.
- **bootc** transports OCI content and manages system deployments.
- **ShapeBit image** defines exact host contents, defaults, policies, and custom
  components.
- **Flatpak** is the default desktop-application boundary.
- **Distrobox/Podman** contains developer toolchains and SDKs.
- **ShapeBit services** provide product behavior without transferring policy to
  UI processes.

Custom desktop components are separate processes managed by systemd user
services. A launcher, panel, or settings failure must not terminate the whole
session.

## 6. Build, release, and trust model

### 6.1 Artifacts

```text
versioned source and Fedora base
        |
RPMs, configuration, and SELinux policy
        |
bootc-compatible OCI image digest
        |
sealed deployment plus signed UKI
        |
signed release manifest
```

The OCI digest identifies the system payload. The signed release manifest is
the complete release identity and binds the payload to its boot artifacts,
compatibility requirements, and security epoch. `developer`, `nightly`,
`testing`, and `stable` are discovery and promotion pointers only.

Production releases are promoted without rebuilding or re-signing the tested
artifact set. Every build records source revision, base image, package versions,
OCI digest, SBOM, signatures, and test results.

### 6.2 Boot trust

The proposed production chain is:

```text
UEFI Secure Boot
-> signed systemd-boot
-> signed UKI carrying the sealed-deployment identity
-> required fs-verity verification
-> PCR 7 plus signed PCR 11 authorization
-> TPM2 unlocks the system LUKS2 volume
-> login surface
```

PCR 7 is directly bound to Secure Boot policy. PCR 11 uses signed expected
measurements so ordinary approved UKI updates do not require sealing to one
fixed value. PCR 0 and PCR 2 are excluded initially because normal firmware and
hardware changes would cause unnecessary recovery. PCR 14 belongs only to a
future shim/MOK design.

Production firmware administration, Secure Boot signing, PCR-policy signing,
release-manifest signing, and device recovery use separate keys. Production
private keys never enter Git, OCI layers, installed disks, logs, or ordinary CI
workers. Development uses visibly distinct disposable keys.

The first supported targets are ShapeBit-controlled reference hardware and
virtual machines. Generic-PC Secure Boot ownership remains an open decision.

### 6.3 Anti-rollback boundary

Retaining accepted and previous signed artifacts creates a bounded rollback
window, not strong anti-rollback. The manifest reserves a non-decreasing
`security_epoch`, but its TPM2 NV enforcement is not yet designed. A separate
ADR must define that mechanism and migration from prototype TPM2 enrollments
before public alpha or persistent production provisioning.

## 7. Filesystem, storage, and state

### 7.1 Ownership model

| Path | Owner | Persistence | Runtime policy |
|---|---|---|---|
| `/usr`, `/opt` | system image | per deployment | read-only |
| `/etc` | device and administrator | persistent | controlled writable configuration |
| `/var` | system services | persistent | service-owned state |
| `/root` | administrator | persistent | encrypted device state |
| `/home/<user>` | user | persistent | mounted only while that home is active |
| `/run`, `/tmp` | runtime | ephemeral | cleared automatically |
| ESP | boot chain | persistent | minimal signed and measured assets |

Vendor defaults belong in `/usr`; local overrides belong in `/etc`; dynamic
state belongs in `/var`. Services use dedicated state, cache, log, and runtime
directories. Caches must be reproducible and disposable.

### 7.2 Proposed disk layout

```text
GPT
├── EFI System Partition
│   └── signed systemd-boot and signed UKIs
└── system LUKS2
    └── Btrfs physical root
        ├── bootc-managed deployments and /usr
        ├── @root
        ├── @var
        │   └── systemd-homed container files
        ├── @snapshots
        └── @recovery-data
```

The system LUKS2 volume protects device state and inactive home-container files
against physical disk access. Each human home remains a separate LUKS2
container with independent credentials. The filesystem inside those containers
is still undecided.

Zram is the default swap. Plaintext disk-backed swap is never supported.
Hibernation remains out of scope until encrypted resume and deployment
compatibility have a separate accepted design.

### 7.3 Persistent-data contract

Every stateful component must publish its data paths, schema version,
compatibility range, migration procedure, backup and restore procedure, and
space requirements. Migrations are idempotent, logged, and verified. A critical
migration failure prevents deployment acceptance; `/var` and `/home` are never
globally rolled back with the system image.

Snapshots are selective safety tools, not backups and not an implicit companion
to every deployment. Each snapshot needs an owner, reason, expiration, and
space limit.

## 8. Authentication and accounts

Every human user has a separate `systemd-homed` LUKS2 container:

```text
password entered once
-> PAM authenticates
-> pam_systemd_home unlocks and mounts the home
-> session starts
```

The home deactivates after the user's final session. The login UI is a PAM
client and does not implement authentication or storage cryptography. Passwords
and recovery keys never appear in an installation plan or transaction log.

Every user receives an independent home recovery key. Every device receives an
independent system-volume recovery key. The initial owner may receive both as
one Recovery Kit presentation, but the keys remain cryptographically and
operationally separate. ShapeBit does not escrow them.

## 9. Updates, trial boot, and rollback

### 9.1 Device state machine

```text
accepted
-> staged
-> pending
-> trial
   |-> accepted
   `-> failed -> rollback-pending -> rolled-back
```

A device retains the booted accepted deployment, one previous accepted
deployment, a pending or trial deployment when present, and recovery outside
normal rotation. Cleanup must not remove artifacts required by any retained
state.

The proposed default is three failed trial boots. A deployment becomes accepted
only after required boot, base-system, device, and critical-migration checks
succeed and a power-loss-safe success marker is written.

### 9.2 Staging invariants

Before reboot, the updater must verify:

- signed manifest and immutable artifact identities;
- signed UKI and sealed-deployment binding;
- sufficient space without deleting the last rollback deployment;
- valid system and recovery LUKS2 keyslots;
- TPM2 authorization for pending and previous accepted UKIs;
- compatible bootloader, updater, hardware, and data schemas.

Staging must be power-loss safe. At every durable transition, at least one
accepted deployment must remain bootable and recoverable without depending on
the incomplete transaction.

### 9.3 Release service

Accepted stable releases are offered in deterministic cohorts. Rollout changes
who discovers a manifest; it never changes that manifest or rebuilds its
artifacts. A release service can suspend discovery, block a digest, or publish a
superseding release. Repointing a channel does not remediate devices already
running a withdrawn release.

## 10. Recovery operations

These operations are intentionally distinct:

| Operation | System deployment | Device state | User homes |
|---|---|---|---|
| rollback | select previous accepted deployment | preserve | preserve |
| backup restore | independent | restore selected data | restore selected data |
| system reset | restore known system and clear host configuration | reset selected device state | preserve encrypted homes and required account metadata |
| full reset | restore factory system | erase | erase |
| single-user reset | unchanged | remove that account metadata | erase only that user's home |

The proposed recovery environment is a separately versioned, minimal signed
image outside normal deployment rotation. It mounts data read-only by default,
uses the device recovery key when TPM2 unlock is unavailable, and requires a
user's own credential to access that user's home.

## 11. Installer architecture

```text
Dioxus UI (unprivileged)
        |
shared protocol and InstallationPlan
        |
privileged backend
        |
storage, bootc, boot trust, accounts, verification
```

The UI selects policy and displays explicit plans, progress, recovery material,
and errors. The backend owns hardware probing, destructive-operation validation,
partitioning, encryption, installation, enrollment, and final verification.

`InstallationPlan` is serializable and secret-free. Passwords and generated
recovery keys use a separate short-lived enrollment channel. The backend uses
transaction IDs, an explicit state machine, dry-run support, structured events,
strict block-device identity checks, and never reports success before final boot
requirements are verified.

The first integration target is a virtual disk and console-only installed
system. The Dioxus UI follows a tested protocol and mock backend; it does not
define storage policy.

## 12. Application and desktop platform

| Software | Supported delivery mechanism |
|---|---|
| desktop application | Flatpak |
| web application | browser or PWA |
| developer tool | Toolbox/Podman |
| host service | system image |
| driver or kernel module | system image or future controlled extension |

Arbitrary host `dnf install` is not a supported product workflow. Public host
extensions are deferred; future options include image variants and signed
system extensions.

The proposed desktop uses Rust, Smithay, Wayland, systemd user services, D-Bus,
PipeWire, portals, libinput, Mesa, DRM, and KMS. Initial compositor scope is a
nested backend, one output, keyboard and pointer input, focus, basic window
management, logging, and application launch. The login surface remains separate
from session locking and uses PAM as described above.

## 13. Development, CI, and release flow

```text
fast:        edit -> build -> nested/local test
integration: edit -> RPM -> bootc image -> QEMU
release:     merge -> CI -> artifacts -> controlled signing -> tests -> promotion
```

Stable systems are not modified manually. Development uses containers, VMs,
temporary overlays, or a developer-channel image.

The target pipeline is:

```text
lint -> unit tests -> RPMs -> image -> bootc lint -> security scan
-> controlled signing -> QEMU boot -> Secure Boot and TPM2 tests
-> service and desktop tests -> update and rollback tests -> publish
```

Stable must be the exact digest and signed artifact set that passed testing.

## 14. Architecture work queue

This is the current planning queue. Complete it before expanding implementation
scope beyond disposable prototypes.

### A0 — documentation structure

- [x] Establish ADRs as the authority for durable decisions.
- [x] Add an ADR index and decision ownership map.
- [x] Remove duplicated architecture sources.
- [x] Consolidate system design, status, roadmap, and task tracking here.
- [ ] Review and explicitly accept, revise, or reject every proposed ADR.

### A1 — deployment lifecycle

- [ ] Assign the sole writer for each deployment-state transition.
- [ ] Select the power-loss-safe state and boot-attempt storage mechanism.
- [ ] Define exact success, failure, intentional-shutdown, and power-loss rules.
- [ ] Decide the minimum health observation period.
- [ ] Define the rollback barrier and N/N-1 data compatibility contract.
- [ ] Reconcile the final design into ADR-0004 and ADR-0007.

### A2 — release and trust lifecycle

- [ ] Specify the signed release-manifest schema and signature envelope.
- [ ] Define how UKI, sealed deployment, OCI digest, and PCR policy are bound.
- [ ] Define signing ownership, rotation, revocation, and compromise response.
- [ ] Decide the generic-PC Secure Boot ownership model or explicitly defer it
  to a named milestone.
- [ ] Create a separate TPM2 NV anti-rollback ADR.
- [ ] Define invalidation and migration of prototype TPM2 enrollments.
- [ ] Review ADR-0006 and ADR-0013 for acceptance after these decisions.

### A3 — storage and recovery lifecycle

- [ ] Confirm Btrfs subvolumes and the inactive home-container location.
- [ ] Select Btrfs or ext4 inside per-user home containers.
- [ ] Define low-space reserves, quotas, and snapshot retention.
- [ ] Specify system-reset preservation of account metadata and home containers.
- [ ] Select recovery UI form and independent recovery update strategy.
- [ ] Define recovery behavior after Btrfs corruption.
- [ ] Review ADR-0002, ADR-0003, ADR-0005, and ADR-0008 for acceptance.

### A4 — installer contract

- [ ] Define versioned `InstallationPlan`, event, error, and capability schemas.
- [ ] Define the secret-enrollment channel and memory-lifetime requirements.
- [ ] Define transaction phases, cancellation points, and resume behavior.
- [ ] Define stable disk identity and destructive-operation confirmation rules.
- [ ] Define the Recovery Kit presentation and verification flow.
- [ ] Map every installation operation to its governing ADR.

### A5 — product and platform contracts

- [ ] Define supported reference hardware and VM profiles.
- [ ] Define the versioned platform-service API boundary.
- [ ] Define Flatpak source, verification, and permission presentation policy.
- [ ] Define diagnostic-report schema and privacy rules.
- [ ] Define developer-mode guarantees and unsupported host modifications.

## 15. Delivery roadmap

Tasks below are implementation outcomes. They remain unchecked until verified,
even when supporting scripts or documentation already exist.

### M0 — architecture baseline

- [x] Select Fedora bootc.
- [x] Select Dioxus for the installer frontend.
- [x] Select per-user encrypted homes.
- [x] Select TPM2-unlocked system-volume encryption.
- [ ] Complete A1-A5 and review all proposed ADRs.

### M1 — bootable secure console prototype

- [ ] Build and lint the bootc container image reproducibly.
- [ ] Create a VM disk and boot it through UEFI to a TTY.
- [ ] Add signed UKI boot under OVMF Secure Boot.
- [ ] Add sealed-deployment verification.
- [ ] Add system LUKS2 with TPM2 automatic unlock and recovery key.
- [ ] Add Btrfs persistent-state layout and zram.
- [ ] Add one `systemd-homed` user with one-password TTY login.
- [ ] Record positive, rejection, recovery, and power-loss evidence.

### M2 — update and rollback prototype

- [ ] Produce signed releases A and B from immutable artifact sets.
- [ ] Stage B while preserving A.
- [ ] Authorize TPM2 unlock for both pending and rollback UKIs.
- [ ] Accept a successful trial boot.
- [ ] Automatically return to A after failed trial boots.
- [ ] Exercise compatible and failed persistent-data migrations.
- [ ] Produce a diagnostic report for every transition.

### M3 — installer backend and protocol

- [ ] Implement the shared protocol and secret-free installation plan.
- [ ] Implement validation, dry run, events, and mock operations.
- [ ] Implement the privileged backend against a virtual disk.
- [ ] Install the M1 system and verify first boot.
- [ ] Verify recovery keys and interruption reporting.

### M4 — Dioxus installer

- [ ] Connect the UI to the mock backend.
- [ ] Complete accessibility and destructive-action UX review.
- [ ] Connect the UI to the real backend.
- [ ] Install to a virtual disk and boot to a TTY.

### M5 — automated release pipeline

- [ ] Build RPMs and bootc images in CI.
- [ ] Generate SBOMs, manifests, attestations, and test reports.
- [ ] Integrate restricted boot and policy signing.
- [ ] Automate boot, update, rollback, recovery, and rejection tests.
- [ ] Promote identical digests through developer, nightly, testing, and stable.

### M6 — desktop platform

- [ ] Implement versioned platform services.
- [ ] Implement the nested Smithay compositor.
- [ ] Add shell, launcher, panel, notifications, and settings.
- [ ] Add PAM-based greeter and separate lock screen.
- [ ] Boot a complete session in a VM.

### M7 — reference hardware and recovery

- [ ] Validate the supported hardware matrix.
- [ ] Validate production key rotation and revocation.
- [ ] Implement and validate TPM2-backed anti-rollback.
- [ ] Harden recovery, reset, backup export, and installer behavior.
- [ ] Pass storage corruption, low-space, and power-loss testing.

### M8 — developer preview

- [ ] The team can install, update, recover, and use ShapeBit OS daily.

### M9 — public alpha

- [ ] No persistent device retains prototype trust enrollment.
- [ ] Stable rollout, diagnostics, recovery, and factory reset are operational.
- [ ] The published hardware scope and security claims match verified evidence.

## 16. Explicitly deferred work

- arbitrary generic-PC support;
- shim/Microsoft signing or owner-managed Secure Boot keys;
- hibernation and encrypted resume;
- public host-extension ecosystem;
- XWayland unless required by the application target;
- offline update bundles;
- complete cloud backup;
- polished consumer onboarding and application ecosystem.
