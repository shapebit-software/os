# Base System

Fedora and bootc foundations, filesystem and storage ownership, hardware scope, capacity policy, platform services, host customization, and validation evidence.

These pages are living architecture, not implementation evidence. Unlabeled
sections describe the current design. A **Proposed** label marks a section that
still requires explicit review and validation; remove the label once that review
is complete.

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## System boundaries

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

- Fedora provides the kernel, Mesa, systemd, RPM infrastructure, and base
  packages.
- bootc transports OCI content and manages system deployments.
- The ShapeBit image defines exact host contents, defaults, policies, and
  custom components.
- Flatpak is the default desktop-application boundary.
- Distrobox and Podman contain developer toolchains and SDKs.
- ShapeBit services provide product policy without transferring system
  authority to UI processes.

## Current implementation evidence

The coordination repository currently links separate `image`, `installer`,
`desktop`, and documentation repositories. The image repository contains a
console-image scaffold plus build, VM, and container-test scripts. The
installer repository currently contains design and protocol documentation.

This evidence does not establish a successful image build, disk-image build,
UEFI boot, login, secure boot chain, TPM unlock, working installer, or working
desktop. The delivery roadmap below remains unchecked until each outcome has
appropriate build or runtime evidence.

## Core platform

### Fedora + bootc as the System Base


#### Purpose and constraints

ShapeBit OS requires a modern desktop stack, atomic updates, rollback, systemd, good Wayland support, and the ability to build custom images.

Options considered:

- Fedora + bootc;
- Arch + custom A/B;
- Debian + A/B/dm-verity;
- openSUSE MicroOS.

#### Design

ShapeBit OS will initially be built as a derivative Fedora bootc image.

#### Why this design

- ready-made image-based model;
- OCI images;
- close alignment with systemd, PipeWire, NetworkManager, Flatpak, and SELinux;
- modern kernel and Mesa;
- straightforward CI/CD;
- lower cost of creating a secure updater than with Arch;
- ability to focus on the desktop and UX.

#### Benefits

- rapid prototype development;
- transactional deployments;
- simpler release channels;
- rollback;
- straightforward image versioning and signing.

#### Tradeoffs

- no native Fedora rolling release;
- periodic migrations between Fedora base versions;
- dependency on RPM/DNF, SELinux, and the bootc ecosystem;
- need to track Fedora Image Mode maturity.

#### Review conditions

Re-evaluate the decision after reaching M3 or if bootc presents major limitations.

#### Ownership boundaries

This section selects the system base and deployment technology. It does not select
the filesystem, encryption, boot trust, release identity, or user interface.

### Filesystem Ownership Boundaries

**Status:** Proposed

#### Purpose and constraints

An image-based system requires a clear separation between code, machine configuration, and persistent state. Without it, image rollback may conflict with local changes.

#### Design

- `/usr` and `/opt` belong to the image and are read-only during normal operation.
- `/etc` stores only device and administrator configuration.
- `/var` stores persistent service state.
- `/home` stores user data and preferences.
- `/run` and `/tmp` are ephemeral.
- vendor defaults should be placed in `/usr`, not `/etc`, when supported by the component.

This section defines logical ownership, not the partition table, filesystem type,
encryption topology, snapshot policy, or migration mechanism.

#### Benefits

- predictable deployments;
- auditable changes;
- simpler image rollback;
- less configuration drift.

#### Tradeoffs

- some existing software will require changes;
- persistent host data must obey the forward-migration and trial-rollback
  contract;
- administrators cannot treat the host like a traditional Fedora installation.

#### Review criteria

Review after the first working update + rollback in M2.

### Btrfs for Persistent System State


#### Purpose and constraints

ShapeBit OS needs a small, understandable set of storage boundaries, checksums,
and shared-space management for persistent system state. Encryption is a
separate system-volume decision. Snapshot policy is deliberately not part of
this decision.

#### Design

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
[No Managed Snapshots](base-system.md) defines that the initial product creates no managed snapshots.

Human home directories are not a shared `@home` subvolume. Each human user has
an independently encrypted LUKS2 home managed by `systemd-homed`, as decided in
[Per-User Encrypted Homes](security-identity.md). The base system/deployment
remains managed by bootc. The exact bootc deployment layout is not a Btrfs
subvolume contract owned by this section.

Inactive `systemd-homed` container files are stored in `@homes` and exposed at
the systemd-homed path selected by implementation. They receive physical-disk
protection from the outer system LUKS2 volume but retain their own per-user
encryption. Keeping them outside `@state` allows system reset to preserve homes
without preserving ordinary host state.

[Initial Installation and Storage Profile](base-system.md) selects Btrfs inside each user's LUKS2 home and a dynamic shared home
capacity pool. This section still owns only the outer persistent-system-state
filesystem and its detailed subvolume layout.

#### Why this design

- encryption of persistent system state;
- subvolumes without rigid space partitioning;
- checksums;
- compression;
- future send/receive capability.

#### Risks

- more complex recovery;
- behavior when full;
- need for power-failure testing;
- a future snapshot feature would add retention and capacity complexity.

#### Corruption policy

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

#### Validation plan

- low-space tests;
- simulated power loss;
- scrub and recovery;
- read-only diagnostics and export after simulated structural corruption;
- independent activation and recovery of multiple encrypted user homes;
- tests on several NVMe/SATA disks.

#### Alternative

LUKS2 + ext4/XFS if Btrfs testing does not meet the M7 criteria.

## Storage and capacity

### Initial Installation and Storage Profile


#### Purpose and constraints

The initial installer needs one storage profile that can be validated safely,
recovered independently, and tested consistently. Alongside installation,
manual partitioning, and several home-allocation modes would multiply
destructive and low-space failure cases before the core lifecycle is proven.

#### Design

##### Disk ownership

- The initial installer takes exclusive ownership of one explicitly selected
  physical disk.
- It does not shrink existing partitions, install alongside another system, or
  offer manual partitioning.
- Installation erases the selected disk after strict identity validation and
  destructive-action confirmation.
- Other physical disks remain untouched.
- Eligible external disks are permitted under the identity and additional
  confirmation rules in [Installer Disk Identity and Confirmation](boot-system-lifecycle.md); the running installer medium is never a
  target.
- Same-disk dual boot is deferred even though the Microsoft-signed shim model
  preserves a future compatibility path.

##### Initial layout

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

##### Home capacity policy

- Human users use the independent LUKS2 containers defined by [Per-User Encrypted Homes](security-identity.md).
- Btrfs is the filesystem inside every human-user LUKS2 home.
- Homes share a dynamically managed capacity pool rather than fixed partitions
  or permanently preallocated sizes.
- Every home has a guaranteed minimum plus access to a shared burst pool.
- Burst capacity follows actual use by default; the device owner may set
  explicit limits as defined by [Capacity and Low-Space Policy](base-system.md).
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

[Capacity and Low-Space Policy](base-system.md) defines the numerical home minimum, reserve formula, quotas, burst
admission, cleanup, and warning thresholds. [No Managed Snapshots](base-system.md) defines that ShapeBit does
not create managed snapshots. A snapshot of an active outer `.home` image is
not considered a valid backup of the inner filesystem.

#### Why this design

Exclusive disk ownership gives the installer one safe and testable destructive
contract. A recovery UKI on the ESP remains bootable after system-filesystem
damage. Btrfs inside each home provides checksums, compression before
encryption, and online resizing needed by a dynamic shared pool.

#### Benefits

- The first installer avoids filesystem shrinking and ambiguous layouts.
- Recovery does not depend on mounting the damaged system volume.
- Home capacity can adapt to actual use without rigid partitioning.
- The same recovery image can serve local and external recovery paths.

#### Tradeoffs

- Same-disk dual boot and manual layouts are unavailable.
- Installation requires erasing a complete selected disk.
- Nested Btrfs and dynamically sized LUKS home images require careful low-space
  and fragmentation testing.
- An attacker may delete an unencrypted ESP recovery image and cause denial of
  service, although modification cannot create a trusted recovery image.

#### Ownership boundaries

This section owns the initial installer disk-ownership contract, recovery-image
placement, per-user filesystem choice, and dynamic home-pool model. [Btrfs for Persistent System State](base-system.md)
owns the detailed outer Btrfs subvolume layout. [Independent Recovery Environment](diagnostics-recovery.md) owns recovery
operations and lifecycle. [Capacity and Low-Space Policy](base-system.md) owns capacity accounting and low-space
behavior. [No Managed Snapshots](base-system.md) owns snapshot policy.

#### When to revisit

- Same-disk dual boot becomes an accepted product requirement.
- The minimal recovery environment no longer fits safely on the ESP.
- Btrfs-in-LUKS homes fail low-space, recovery, or performance validation.
- A fixed-allocation or separate-home-partition product profile is introduced.

### Capacity and Low-Space Policy


#### Purpose and constraints

[Initial Installation and Storage Profile](base-system.md) establishes dynamically sized encrypted homes, a shared burst pool,
and a protected system reserve. ShapeBit needs exact accounting rules so that
ordinary home growth cannot consume the space required for updates, trial
rollback, recovery, and basic system operation.

#### Design

##### Protected system reserve

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

The installed current deployment, a pending or trial deployment, its required
rollback baseline, and recovery assets are actual protected allocations. Their
occupied bytes are deducted before home capacity is offered and are not counted
a second time in the free-space reserve. An old deployment cached after durable
acceptance is ordinary system use, not a protected rollback allocation, and may
be cleaned up. Filesystem accounting must use allocated physical space, not
apparent sparse-file size.

An approved system operation may consume its own reserve component and must
release unused workspace when it completes. Home growth cannot consume any
reserve component.

##### Home guarantees and limits

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

##### Low-space states

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

##### Cleanup and warnings

Entering the critical state triggers bounded automatic cleanup of system-owned
data explicitly classified as rebuildable. Examples include abandoned update
download fragments, expired system temporary files, logs beyond their owning
retention policy, and caches with a tested rebuild path.

Automatic cleanup never removes:

- user files, application data, or application caches;
- Flatpaks or AppImages;
- the current deployment, a pending or trial deployment, or its required
  rollback baseline;
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

##### Insufficient space for a system operation

Before downloading or staging an update, ShapeBit checks the signed declared
space requirement. If the operation cannot complete while preserving the
reserve, existing home data, and unused guarantees, it does not start or safely
pauses before exhausting admissible space. It blocks new accounts and limit
increases while the shortage remains and tells an administrator how much space
is missing and which safe actions are available.

The rule also applies to security updates. Urgency does not authorize ShapeBit
to delete user data, revoke occupied capacity, or breach the reserve.

#### Tradeoffs

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

#### Ownership boundaries

This section owns numerical reserve inputs, home guarantees and limits, shared-burst
admission, low-space states, warnings, and safe cleanup boundaries. [Initial Installation and Storage Profile](base-system.md)
owns the installation storage profile and dynamic-home model. [Btrfs for Persistent System State](base-system.md) owns the
outer Btrfs structure and corruption policy. [No Managed Snapshots](base-system.md) owns snapshot behavior;
unmanaged snapshots count as real allocated capacity under this policy.

### No Managed Snapshots


#### Purpose and constraints

Btrfs can create cheap copy-on-write snapshots, but cheap creation does not
make retention, capacity accounting, consistency, or recovery semantics free.
ShapeBit already uses bootc deployments for system-image rollback and keeps
prepared host state compatible with the rollback baseline until trial
acceptance. Each human home is also a separate active filesystem inside an
encrypted container file, which an outer snapshot cannot safely represent as a
general file-level recovery point.

The initial product needs one clear recovery model and predictable low-space
behavior more than it needs an additional checkpoint mechanism.

#### Design

##### Managed scope

The initial ShapeBit release creates no managed Btrfs snapshots. This applies
to outer `@root`, `@state`, `@homes`, and `@recovery` subvolumes and to the Btrfs
filesystem inside every user home.

ShapeBit does not create scheduled snapshots, pre-update snapshots,
pre-administration snapshots, migration snapshots, or user file-history
snapshots. It exposes no ordinary Settings, Files, or recovery action for
creating or restoring them. The initial layout retains no `@snapshots`
subvolume.

Because ShapeBit owns no snapshots, it has no managed snapshot retention or
automatic snapshot-deletion schedule. A future ShapeBit feature that creates a
snapshot requires a new accepted decision defining its consistency point,
owner, capacity budget, retention, deletion, and recovery semantics.

##### Relationship to rollback and backup

Bootc deployment selection and [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) trial rollback remain the only managed
system-version rollback mechanism. They do not restore persistent user or
device data and are not described as filesystem snapshots.

A snapshot is never represented as a backup. A backup must have an independently
defined export, integrity, encryption, retention, and restore contract and must
survive loss of the source disk. A snapshot of an outer active `.home` container
is not a valid backup or supported restore point for its inner filesystem.

##### Unmanaged snapshots

ShapeBit does not intentionally block an administrator or developer tool from
creating a Btrfs snapshot outside the supported product interface. When it
detects such a snapshot, it:

- leaves the snapshot and its contents untouched;
- never deletes it automatically, including under low-space pressure;
- accounts for its physical allocation as unmanaged system data;
- reports its presence and capacity impact in storage diagnostics; and
- warns that it may prevent updates or other operations from meeting the
  [Capacity and Low-Space Policy](base-system.md) reserve contract.

ShapeBit does not accept responsibility for the snapshot's consistency,
retention, restoration, or deletion. [Host Customization and Integrity Status](base-system.md) determines the resulting support
status as part of the broader host-customization policy.

#### Tradeoffs

- Initial rollback, recovery, and low-space behavior remain small and
  understandable.
- Snapshot retention cannot silently consume the protected system reserve.
- ShapeBit provides no built-in previous-version file recovery and no local
  checkpoint before administrator changes.
- Bootc rollback does not undo a harmful persistent-data change; [Forward-Only Migrations and Trial-Bounded Rollback](boot-system-lifecycle.md)'s
  compatible `prepare` boundary remains essential.
- Externally created snapshots remain possible for development, but ShapeBit
  neither manages nor automatically removes them.

#### Ownership boundaries

This section owns managed snapshot scope, the absence of retention and deletion,
handling of unmanaged snapshots, and the distinction between snapshot,
deployment rollback, and backup. [Btrfs for Persistent System State](base-system.md) owns the Btrfs layout. [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) owns
deployment rollback. [Capacity and Low-Space Policy](base-system.md) owns capacity accounting and low-space behavior.
[Host Customization and Integrity Status](base-system.md) owns the support status of modified host state. A future backup design
must be recorded separately.

## Platform services and host integrity

### Platform-Service API Contract



#### Purpose and constraints

ShapeBit desktop components are unprivileged, while updates, storage policy,
accounts, power management, remote access, trust changes, diagnostics, and
recovery preparation require narrowly scoped system authority. A stable
internal contract is needed so that UI restarts and service failures do not
turn those operations into an implicit root boundary or ambiguous transaction.

#### Design

##### Service boundaries and names

ShapeBit uses separate system-bus services for distinct privilege domains:

| D-Bus service name | Responsibility |
|---|---|
| `software.shapebit.update` | check, download, verify, and stage system updates |
| `software.shapebit.storage` | capacity, home limits, reserve state, and safe cleanup |
| `software.shapebit.accounts` | account creation, removal, roles, and encrypted-home policy |
| `software.shapebit.power` | lid, suspend, battery, power profiles, thermals, and charge limits |
| `software.shapebit.remote_access` | system SSH and privileged sharing coordination |
| `software.shapebit.trust` | test channels, local trust keys, and trust-domain changes |
| `software.shapebit.diagnostics` | report creation, inspection, and export |
| `software.shapebit.recovery` | recovery-boot preparation and recovery-operation requests |
| `software.shapebit.platform` | read-only aggregate readiness and API inventory |

Each name is lowercase. Underscores separate words where necessary. D-Bus
names and object paths contain no hyphens; corresponding systemd units and
executables use hyphens, for example `shapebit-update.service` and
`shapebit-update`.

The platform service is not a privileged mutation proxy. It reports only
aggregate readiness, service availability, and supported interface versions.
The other eight services remain separately restartable and receive only the
authority needed for their domain.

ShapeBit does not wrap a stable upstream API merely to rename it. Desktop
components may use NetworkManager, logind, systemd-homed, PipeWire, and other
upstream interfaces directly where no ShapeBit-specific privileged policy is
required.

##### Interface versioning and audience

The well-known service name and primary object path remain stable. The major API
version is a separate lowercase interface element:

```text
service:   software.shapebit.update
interface: software.shapebit.update.v1
object:    /software/shapebit/update
unit:      shapebit-update.service
```

Compatible additions retain the same major interface. An incompatible change
creates `.v2`; it never silently changes the meaning of a `.v1` method,
property, signal, or error. A daemon may expose both versions during development
or transition.

These interfaces are internal ShapeBit APIs, not a public third-party SDK.
ShapeBit Flatpaks use standard portals and freedesktop interfaces. AppImages
receive no special platform access. External callers receive no compatibility
or authorization guarantee.

The release contract declares the interface versions required by its in-image
clients and verifies the match before staging. Because bootc switches the whole
deployment and pre-acceptance rollback boots the baseline's own clients and
services, ShapeBit does not retain an unused old interface for a fixed number of
releases. It may remove that version once no supported component in the image
uses it. An interface advertised during one boot does not disappear or change
semantics during that boot.

##### Caller identity and authorization

Every method belongs to exactly one authorization class:

- **non-sensitive status** available without privilege elevation;
- **own-user operation** restricted to state owned by the authenticated caller;
- **administrator operation** decided by Polkit; or
- **internal system operation** restricted to an explicit ShapeBit service.

The service obtains peer credentials from the D-Bus connection and session
state from logind. It never treats a caller-supplied UID, user name, role, bus
name, process ID, or session identifier as proof of identity. A method declares
whether an SSH session is allowed and whether an unlocked active local session
is required.

System-to-system methods combine restricted D-Bus name ownership with systemd
service identity and SELinux policy. Executable paths supplied by callers are
not identity. Passwords and authentication secrets never become D-Bus method
arguments; the trusted Polkit agent handles them under [Desktop Session and Authorization Boundaries](desktop.md). Authorization
is completed before a privileged job is admitted.

##### Synchronous calls and asynchronous jobs

Bounded status reads and short non-transactional changes may return directly.
An operation that can outlive a method call, has progress, or requires durable
state returns an asynchronous job object immediately.

Every job exposes an opaque identifier, operation type, sanitized initiating
identity, creation time, state, current phase, optional progress, result, and
structured failure. Its state is one of:

```text
queued | running | succeeded | failed | cancelled | interrupted
```

D-Bus signals are change hints. A client that starts or reconnects reads the
authoritative current state rather than reconstructing it from signals. Closing
the shell or Settings does not cancel system work. A job is cancellable only
when its operation declares a safe cancellation point, and cancellation is
authorized like the original operation.

Mutation requests carry an opaque caller-generated idempotency token. Repeating
the same authorized operation with that token returns the existing job or
result instead of starting a duplicate. Reusing a token for different arguments
returns `conflict`.

Power-loss-sensitive jobs store the minimum transaction state required by their
own architecture section in `@state` and reconstruct the same identifier after a service restart.
A non-durable active job that cannot resume becomes `interrupted`.

##### Common error contract

A rejected synchronous request returns a D-Bus error. Failure after job
admission is recorded on the job with state `failed`. Both forms provide the
same structured fields:

- a stable machine code;
- a localization key and safe parameters;
- retry guidance;
- and an optional diagnostic-report identifier.

The initial common codes are:

```text
invalid_request
not_supported
not_authorized
not_active_session
conflict
busy
insufficient_space
unavailable
integrity_failure
cancelled
interrupted
internal
```

Services do not expose raw library messages, backtraces, secrets, or arbitrary
host paths as user-facing errors. A client that does not recognize a code shows
a safe generic failure. [Diagnostic Reports and Consent](diagnostics-recovery.md) owns diagnostic detail and redaction.

##### Process and job lifecycle

All services run under systemd and do not self-daemonize. `platform` and
`power` remain resident. `update` is activated by a timer, network event, or
explicit request. `storage`, `accounts`, `remote_access`, `trust`, and
`recovery` use D-Bus activation. `diagnostics` is activated by D-Bus or a fault
event, and the boot-health contract performs a write transaction before
acceptance.

Systemd may restart a failed service under a bounded restart policy. Clients
must tolerate loss and reacquisition of a well-known bus name and must not bind
correctness to a daemon PID. Durable state remains authoritative across a
process restart.

An active job remains queryable until it reaches a terminal state. A terminal
job remains queryable for 24 hours, subject to a maximum of 100 terminal jobs
per service. When the limit is exceeded, the oldest terminal job may be removed
early. Removing a D-Bus job object does not remove a required transaction log
or diagnostic report. [Diagnostic Reports and Consent](diagnostics-recovery.md) owns retention of those records. A UI may hide
an acknowledged result earlier without deleting the system record.

#### Tradeoffs

- Privilege and crash domains remain narrow and independently testable.
- Common identity, job, error, and lifecycle rules reduce custom behavior in
  each settings panel.
- The stable bus name and explicit `.v1` interface make incompatible changes
  visible without imposing a public SDK promise.
- Asynchronous jobs survive UI restarts and prevent accidental duplicate
  transactions.
- Multiple services, activation policies, Polkit rules, SELinux labels, and
  shared contract tests require more packaging than one privileged daemon.
- Upstream services remain visible architectural dependencies rather than being
  hidden behind unnecessary wrappers.

#### Ownership boundaries

This section owns ShapeBit platform-service names, API audience, versioning, caller
identity, authorization classes, asynchronous jobs, common errors, activation,
and job-object retention. Domain architecture sections own the actual policy of each operation.
[Desktop Session and Authorization Boundaries](desktop.md) owns the desktop authorization experience and credential cache.
[Diagnostic Reports and Consent](diagnostics-recovery.md) owns diagnostic schemas, redaction, consent, and record retention.
[Boot Health Contract](boot-system-lifecycle.md) owns the boot-health decision that consumes the aggregate readiness
endpoint.

### Host Customization and Integrity Status


#### Purpose and constraints

Bootc updates the image-owned system while preserving host-specific `/etc` and
`/var` state. ShapeBit therefore needs to distinguish supported configuration,
ordinary administrator customization, and actual loss of trust in protected
boot or image artifacts. Treating every writable-host change as an integrity
failure would make normal administration unusable; treating every root change
as supported would make diagnostics and recovery misleading.

The initial mechanism must remain diagnostic and simple. It is not intended to
defend its own records from an already-authorized malicious root process.

#### Design

##### Configuration layers

ShapeBit components use these ownership and precedence layers:

```text
built-in program defaults
< /usr/lib/shapebit/<component>   image-owned vendor configuration
< /run/shapebit/<component>       temporary runtime overrides
< /etc/shapebit/<component>       persistent local overrides
```

`/var/lib/shapebit/<component>` stores mutable service state, not administrator
configuration. A lower line in the diagram has higher precedence. Local files
store the smallest practical override rather than a full copy of vendor
configuration.

ShapeBit follows equivalent upstream `/usr/lib`, `/run`, and `/etc` precedence
where a component already defines it. Software that cannot separate vendor
defaults from local configuration requires an explicit migration plan with a
rollback-compatible `prepare` phase; ShapeBit does not assume that bootc will
semantically merge its configuration.

##### Status model

The device exposes three current statuses:

- **Managed**: controlled writable configuration matches the state created by
  ShapeBit or a supported API, and protected artifacts pass integrity checks;
- **Customized**: a controlled writable host area contains a local change not
  represented by the supported configuration state; and
- **Integrity failure**: a signed, measured, or otherwise protected image,
  boot, mandatory SELinux, or trust-domain artifact fails its authoritative
  verification.

Flatpaks, AppImages, Distrobox containers, ordinary user files, and enabling
developer mode do not make the host `Customized`. A supported trust change made
through `software.shapebit.trust` is managed state, not an integrity failure.

`Customized` is recomputed and reversible. Returning every controlled path to
its expected state returns the device to `Managed`; it is not a permanent
record that customization once occurred.

##### Simple customization detection

A root-owned manifest in protected system state records the current expected
configuration produced through ShapeBit and supported upstream APIs. For each
managed file it records only the path, content digest, owner, mode, and expected
file type. Manifest replacement is atomic. It does not duplicate file contents
or serve as integrity authority for the image or boot chain.

The scanner is intentionally allowlisted rather than a hash of all `/etc`. Its
initial controlled scope covers:

- `/etc/shapebit`;
- systemd system units and drop-ins under `/etc/systemd/system`;
- local Polkit policy and rules;
- udev, kernel-module, and sysctl overrides;
- SSH server configuration;
- SELinux local policy and configuration;
- boot and local trust configuration; and
- NetworkManager system-connection configuration tracked after supported API
  operations.

A changed expected file, unexpected entry, wrong type, owner, or mode in this
scope produces `Customized` unless an authoritative protected-artifact check
classifies it as an integrity failure. Areas outside the allowlist are not
claimed to be assessed in the initial product.

The scan runs during boot diagnostics, before update staging, after a supported
administrator operation, and on explicit diagnostic request. Its report lists
differences without copying secret file contents. This mechanism detects
ordinary drift; root can alter both configuration and the manifest, so it is
not a security boundary.

##### Behavior of a customized system

A `Customized` system continues to boot and update. Secure Boot, trial boot,
rollback, recovery, and other protections remain active. Settings and
Diagnostics show the changed paths and associate a change with the affected
support area where possible.

Support is limited only for behavior plausibly affected by the customization;
an unrelated subsystem does not lose its support status. Reports record the
relevant differences. ShapeBit never overwrites or deletes a customization
merely because it was detected.

Update staging is blocked only when a concrete difference prevents safe
staging or violates a declared compatibility requirement of the new release.
The diagnostic result must name the blocking requirement and affected path.

##### Integrity-failure behavior

Protected image and boot artifacts use their signed manifests, measurements,
and trust policy rather than the customization manifest. An integrity failure
during a trial boot is a deterministic hard failure under [Boot Health Contract](boot-system-lifecycle.md). Before
normal startup, ShapeBit selects the previous trusted deployment or independent
recovery when none exists. The failed deployment is locally blocked from
automatic selection and produces a critical diagnostic report.

If an integrity failure is detected in an already running accepted deployment,
ShapeBit blocks new privileged mutations and update staging, writes the minimal
critical report, selects the previous trusted deployment, and performs a
controlled restart after a brief critical warning. Preserving unsaved work does
not override loss of trust. If no trusted deployment exists, the restart enters
independent recovery.

There is no **Ignore** or **Mark trusted** action for a failed artifact. Only an
explicitly authorized trust-domain operation or installation of a correctly
verified deployment can establish trust.

##### Restoring managed configuration

An active local administrator may restore one detected customization or all of
them. Before authorization, ShapeBit shows the exact files that it will remove,
replace, or recreate. The operation reconstructs the current image defaults and
supported settings without using a filesystem snapshot.

Before changing a file, ShapeBit copies the original into a root-only encrypted
quarantine in `@state`. Quarantined files are data and are never executed. The
replacement is atomic, and failure restores the pre-operation state. The same
operation is available from independent recovery when customization prevents
normal startup.

Quarantine entries expire after 30 days and have a combined limit of 256 MiB.
An administrator may undo a restoration while its complete entry remains. If a
new restoration would exceed the limit, ShapeBit stops before making changes
and offers manual export; it does not evict an existing entry silently to admit
the new operation.

#### Tradeoffs

- Vendor defaults update atomically with `/usr`, while local overrides survive
  bootc deployment changes.
- A bounded allowlist is understandable and testable, but does not claim to
  detect every possible `/etc` customization.
- Advanced administration remains possible without disabling unrelated support
  or system updates.
- The customization manifest improves diagnostics but cannot attest against a
  hostile root process.
- Restoration is reversible without adding the managed snapshot mechanism that
  [No Managed Snapshots](base-system.md) rejects.
- Confirmed loss of protected-artifact trust prioritizes a trusted restart over
  an active session's unsaved work.

#### Ownership boundaries

This section owns ShapeBit configuration layering, host-status classification,
allowlisted customization detection, support effects, integrity-failure
response, and configuration restoration quarantine. [Filesystem Ownership Boundaries](base-system.md) owns general
filesystem ownership. [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns boot trust and authorized trust-domain
changes. [Boot Health Contract](boot-system-lifecycle.md) owns trial-boot hard-failure transitions. [No Managed Snapshots](base-system.md) owns the
absence of managed snapshots. [Diagnostic Reports and Consent](diagnostics-recovery.md) owns diagnostic report data handling.

## Hardware scope and validation

### Platform Scope and Hardware Validation


#### Purpose and constraints

ShapeBit OS needs a reproducible virtual target, a realistic path to physical
hardware, and hardware claims that do not imply untested generic-PC support.
Fedora validates the base distribution and many upstream components, but it
does not validate the ShapeBit boot chain, storage policy, recovery behavior,
updates, rollback, or exact hardware integration.

#### Design

##### Supported platform scope

- The initial automated target is x86-64 QEMU with OVMF and a software TPM.
- The official developer host class is Linux x86-64 with KVM. Fedora is the
  canonical host and the required CI environment.
- Other Linux distributions may use the same workflow when they provide the
  required host capabilities and pass the host check.
- macOS, Windows, WSL, ARM64 hosts, and arbitrary hypervisors are outside the
  initial official developer-host scope.
- Physical validation uses existing market-available laptops with upstream
  Linux support. ShapeBit does not define one reference laptop and does not
  initially develop custom hardware.

##### Hardware evidence labels

Every physical hardware result uses exactly one of these evidence labels:

- **Officially-tested** — the ShapeBit team completed the mandatory product
  test suite and published the evidence.
- **Community-tested** — a community member submitted sufficient hardware and
  test information, but the ShapeBit team did not complete the official suite.
- **Unknown** — there is no sufficient current positive evidence. This label
  does not mean incompatible.

Known failures are recorded separately and do not create a fourth evidence
label.

Evidence is scoped to a ShapeBit release, exact hardware configuration, and
firmware version. It does not transfer automatically to a later ShapeBit
release, a similarly named model, or a different SKU.

##### Official test meaning

`Officially-tested` requires the mandatory integration suite, including:

- full-disk installation and ordinary boot;
- Microsoft Secure Boot through the ShapeBit shim;
- TPM2 unlock and device-recovery-key unlock;
- per-user home activation and recovery;
- rejection of modified boot artifacts;
- update, trial boot, acceptance, and pre-acceptance rollback;
- recovery after an interrupted operation;
- required laptop graphics, networking, audio, input, battery, suspend, resume,
  shutdown, and supported firmware behavior.

Results are published as a capability matrix. Optional hardware features may
carry explicit limitations, but a missing mandatory result is not a pass.
[Simple Test Evidence](base-system.md) defines the simple YAML record, mandatory QEMU and physical groups,
overall pass calculation, and minimum community submission.

##### Release gates

- Developer and nightly releases may be published after the complete required
  QEMU suite passes, even when no physical model is `Officially-tested`.
- Stable releases and the public alpha require at least one
  `Officially-tested` laptop for that exact release.
- A critical emergency security release may be published with
  `hardware validation pending` after its mandatory QEMU and security tests
  pass. [Release Cadence and Candidate Aging](boot-system-lifecycle.md) requires physical validation within 72 hours, and the trial
  rollback baseline must remain available until acceptance.

##### Long-term self-hosting

Using the ShapeBit developer channel as the team's primary daily development
host is a distant goal, not an initial release requirement. Fedora remains an
independent bootstrap, CI, and recovery path. ShapeBit must never become the
only environment capable of rebuilding ShapeBit.

Both hosts will eventually use the same pinned ShapeBit SDK container. Build
capability does not grant access to production signing keys.

#### Why this design

This model obtains broad base-system value from Fedora without claiming that
Fedora tested the assembled ShapeBit product. Versioned evidence avoids stale
compatibility claims, while QEMU keeps early development independent of one
physical laptop.

#### Benefits

- Hardware claims have an auditable meaning.
- Early development is not blocked by a specific laptop.
- The physical test matrix can grow without redefining a reference platform.
- Fedora remains a reliable bootstrap while later ShapeBit self-hosting enables
  continuous dogfooding.

#### Tradeoffs

- Stable promotion requires recurring destructive physical tests.
- Hardware evidence expires with each release unless it is renewed.
- Community results cannot carry the same assurance as official results.
- Supporting multiple Linux development hosts requires capability detection.

#### Ownership boundaries

This section owns platform scope, hardware evidence labels, and release-level
hardware gates. It does not define the Secure Boot chain, disk layout, or the
detailed test implementation.

#### When to revisit

- ShapeBit begins developing or shipping custom hardware.
- macOS, Windows, ARM64, or non-KVM development becomes a product requirement.
- The project makes a hardware-support promise stronger than published test
  evidence.

### Simple Test Evidence


#### Purpose and constraints

[Platform Scope and Hardware Validation](base-system.md) defines the QEMU target, physical-hardware labels, and release gates,
but those claims still need a concrete record and pass rule. The initial project
is maintained by one person and does not need a certification platform,
cryptographically signed test database, or a separate evidence object for each
assertion.

#### Design

##### One simple report

Every QEMU or physical-hardware run produces one human-readable YAML report.
It contains:

- ShapeBit version and exact image digest;
- date;
- environment type, `qemu` or `physical`;
- for QEMU, the named standard VM profile;
- for physical hardware, exact model or SKU and firmware version;
- the fixed checklist with `pass`, `fail`, or `not-tested` for every group;
- a short note for each failure;
- references to automatically retained logs for failed automated tests; and
- a mechanically computed overall `pass` or `fail`.

The initial report uses no cryptographic report signatures, separate evidence
schema, or per-test version number. A QEMU report is an ordinary CI artifact. A
physical report is the source for the published capability entry. Repository
history and the publishing account identify provenance in the initial project.

An omitted checklist entry is treated as `not-tested`. An official suite passes
only when every mandatory group is `pass`; `fail` and `not-tested` both make its
overall result `fail`. Logs are required for an automated `fail` but are not
collected as separate evidence objects for every successful check.

Example:

```yaml
release: 0.1.0
digest: sha256:...
date: 2026-08-12
environment: qemu
tests:
  install: pass
  secure-boot: pass
  update: pass
  rollback: fail
  recovery: not-tested
result: fail
```

##### Mandatory QEMU groups

The complete QEMU suite reports these eight groups:

1. installation to an empty disk;
2. boot with Secure Boot enabled;
3. automatic system-volume unlock through the software TPM2;
4. device recovery-key unlock after TPM2 unlock is made unavailable;
5. user creation, login, and activation of the encrypted home;
6. update staging, trial boot, and successful acceptance;
7. automatic rollback after a deliberately failed deployment; and
8. boot of the independent recovery environment.

Each group may contain multiple internal assertions, but it has one report
result. Any failed assertion fails its group. The standard QEMU profile uses
x86-64 KVM, OVMF, Secure Boot, a software TPM2, the defined virtual storage,
network, and display devices, and no undeclared host-specific substitutions.

##### Mandatory physical-hardware groups

An official physical run reports these eight groups:

1. installation, Secure Boot, TPM2 unlock, and device recovery-key unlock;
2. login and encrypted-home activation;
3. update, trial boot, acceptance, and pre-acceptance rollback;
4. built-in display, graphics, brightness, and scaling;
5. keyboard, touchpad, and present input devices;
6. Wi-Fi, Ethernet, and Bluetooth where that hardware is present;
7. speakers, microphone, headphones, and camera where present; and
8. battery reporting, power profiles, lid handling, suspend, and resume.

The report also contains a simple capability table for optional or
model-dependent features such as HDR, VRR, fingerprint readers, and charge
limits. Absence of optional hardware is recorded as absent and does not fail the
suite. If ShapeBit claims support for a present optional capability on that
model, its check must be `pass`; otherwise the published matrix records the
limitation.

`Officially-tested` requires an overall passing physical report performed and
published by ShapeBit for the exact release, hardware configuration, and
firmware version. The report is not transferable to a different release or SKU.

##### Community-tested minimum

A community submission uses the same report and fills every group with `pass`,
`fail`, or `not-tested`. It identifies the exact release digest, model or SKU,
and firmware.

`Community-tested` requires `pass` for:

- installation and ordinary boot;
- login;
- display output;
- keyboard and touchpad;
- at least one network connection;
- audio output; and
- suspend and resume.

Update, rollback, independent recovery, and optional capabilities may remain
`not-tested`. Every reported failure is published as a known limitation. A
blocking failure of installation, login, display, or resume prevents the
`Community-tested` label. ShapeBit reviews the report for completeness and
plausibility but does not claim to have reproduced its results.

Known failures remain separate from the three evidence labels defined in
[Platform Scope and Hardware Validation](base-system.md); this decision does not create another hardware label.

#### Tradeoffs

- Reports are easy to read, generate in CI, and fill during manual laptop
  testing.
- The overall official pass cannot hide a skipped mandatory group.
- Broad groups avoid a large evidence framework, but provide less granular
  history than per-assertion records.
- Successful groups do not retain dedicated proof beyond the report and normal
  CI history.
- Community results are useful for everyday compatibility without being
  presented as official validation.

#### Ownership boundaries

This section owns the initial report shape, result vocabulary, mandatory QEMU and
physical groups, overall pass calculation, and minimum community submission.
[Platform Scope and Hardware Validation](base-system.md) owns platform scope, label meaning, and release gates. [Release Cadence and Candidate Aging](boot-system-lifecycle.md) owns
release timing. A future need for independent auditors, multiple release
maintainers, or machine-verifiable certification may justify a more rigorous
evidence format.

## Planning and delivery

### Architecture work queue

This is the current planning queue. Complete it before expanding implementation
scope beyond disposable prototypes.

#### Remaining decision backlog

This is the canonical ordered list of unresolved architecture work. The A0-A5
sections below retain completed decision history and do not duplicate open
items. Deferred features in section 17 are not counted here.

##### P0 — product behavior that can be decided now

- [x] **D01 — Inbound file sharing:** use SFTP through configured SSH and
  optional per-user SMB 3 sharing as defined by [Inbound File Sharing](security-identity.md).
- [x] **D02 — Authorization cache:** use a fixed, non-renewable five-minute
  Polkit authentication cache as defined by [Desktop Session and Authorization Boundaries](desktop.md).
- [x] **D03 — System application set:** use the exact offline desktop core,
  browser onboarding, integration wrappers, and Distrobox environment defined
  by [Application Platform and System Set](application-platform.md).
- [x] **D04 — Application recommendations:** use sole-curator approval,
  event-driven review without a fixed cadence, and the signed canonical list
  defined by [Application Recommendations](application-platform.md).
- [x] **D05 — Enterprise network credentials:** use the bounded 802.1X, VPN,
  software-certificate, safe-import, and strict server-identity set defined by
  [Enterprise Network Authentication](security-identity.md).
- [x] **D06 — Boot health details:** use the five parallel controls, exact
  timeouts, bounded observation, and failure transitions defined by [Boot Health Contract](boot-system-lifecycle.md).
- [x] **D07 — Staged-restart UX:** use the persistent indicator, bounded
  reminders, explicit actions, and user-controlled restart behavior defined by
  [Staged-Restart UX](boot-system-lifecycle.md).

##### P1 — platform, storage, and release contracts

- [x] **D08 — Capacity policy:** use the protected reserve, home guarantee,
  opportunistic burst pool, low-space states, and cleanup rules defined by
  [Capacity and Low-Space Policy](base-system.md).
- [x] **D09 — Snapshot policy:** create no managed snapshots and treat detected
  unmanaged snapshots as external capacity use under [No Managed Snapshots](base-system.md).
- [x] **D10 — Platform-service API:** use the narrow internal services,
  versioned interfaces, caller classes, asynchronous jobs, structured errors,
  and lifecycle contract defined by [Platform-Service API Contract](base-system.md).
- [x] **D11 — Diagnostics:** use the common envelope, producer-owned payloads,
  global upload consent without previews, bounded retention, and manual export
  defined by [Diagnostic Reports and Consent](diagnostics-recovery.md).
- [x] **D12 — Unsupported host modifications:** use the three host statuses,
  allowlisted drift detection, scoped support effects, strict integrity
  response, and reversible restoration defined by [Host Customization and Integrity Status](base-system.md).
- [x] **D13 — Test evidence schemas:** use one simple YAML report, eight QEMU
  groups, eight physical groups, mechanical official pass, and the community
  minimum defined by [Simple Test Evidence](base-system.md).
- [x] **D14 — Release timing:** target four-week stable releases, require seven
  unchanged days in `testing`, and use the bounded emergency-security exception
  defined by [Release Cadence and Candidate Aging](boot-system-lifecycle.md).

##### P1 — installer contract

- [x] **D15 — Installation protocol schemas:** use the private JSON Lines
  protocol, minimal plan, capability snapshot, optional Wi-Fi, common messages,
  structured events, and string errors defined by [Minimal Installer Protocol](boot-system-lifecycle.md).
- [x] **D16 — Secret enrollment:** use the purpose-bound one-shot channel,
  bounded input lifetime, cancellation, binary framing, and directed Recovery
  Kit transfer defined by [One-Shot Installer Secret Channel](boot-system-lifecycle.md).
- [x] **D17 — Installer transaction lifecycle:** use the six phases, explicit
  destructive boundary, durable checkpoints, conservative resume, declared
  retries, and final verification defined by [Installer Transaction Lifecycle](boot-system-lifecycle.md).
- [x] **D18 — Disk identity and confirmation:** use composite stable identity,
  last-moment validation, one-use confirmation, stale-plan invalidation, and
  explicit external-disk handling defined by [Installer Disk Identity and Confirmation](boot-system-lifecycle.md).
- [x] **D19 — Recovery Kit flow:** use the single offline kit, two independent
  keys, trusted QR/text presentation, encrypted external export, explicit
  acknowledgement, completion gate, and interrupted-presentation replacement
  lifecycle defined by [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md).
- [x] **D20 — Installer architecture mapping:** the installer component maps
  every planned operation to its owning living architecture section and the
  remaining proposed production gates. This is documentation closure rather
  than a new product decision.

##### P1 — release trust and anti-rollback

- [x] **D21 — Release manifest:** use the closed schema-v1 payload, RFC 8785
  JCS, DSSE envelope, computed manifest digest, strict artifact roles, three
  tool compatibility ranges, and external mutable metadata defined in
  [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md). [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) remains proposed until D23 and the G02 review are
  complete.
- [x] **D22 — Artifact binding:** use the OCI-to-composefs-to-UKI binding,
  independent signed forward-only boot stack, A/B ESP transaction, firmware
  fallback, recovery reconstruction, repeated verification, and evidence gates
  defined by [Release Artifact and Rootfs Binding](boot-system-lifecycle.md). [Release Artifact and Rootfs Binding](boot-system-lifecycle.md) remains proposed until its QEMU and physical
  acceptance evidence exists.
- [ ] **D23 — Signing operations:** define production ownership, HSM roles,
  authorization, rotation, audit, and compromise response for every key.
- [ ] **D24 — Strong anti-rollback:** create the TPM2 NV security-epoch architecture section,
  including transitions, rollback window, recovery, and failure behavior.
- [ ] **D25 — Prototype trust migration:** define how early TPM enrollments are
  detected, invalidated, and migrated without preserving an old unlock path.

##### Proposal review gates

- [ ] **G01 — [Filesystem Ownership Boundaries](base-system.md):** review and
  revise filesystem ownership after the required update-and-rollback evidence
  exists, then remove its `Proposed` label.
- [ ] **G02 — [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md):**
  review and revise signed release identity after D21-D23, then remove its
  `Proposed` label.
- [ ] **G03 — [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md):**
  review and revise boot trust after D22-D25 and the required QEMU and physical
  hardware evidence, then remove its `Proposed` label.

#### A0 — documentation structure

- [x] Establish architecture sections as the authority for durable decisions.
- [x] Add system-area indexes and ownership boundaries.
- [x] Remove duplicated architecture sources.
- [x] Consolidate system design, status, roadmap, and task tracking here.

#### A1 — deployment lifecycle

- [x] Select systemd-boot counting and blessing as boot-state authority.
- [x] Define success, failure, intentional-shutdown, and power-loss rules.
- [x] Select two trial attempts and immediate rollback for hard failures.
- [x] Require mandatory checks plus two minutes of healthy observation.
- [x] Replace indefinite N/N-1 compatibility with forward-only migrations.
- [x] Split incompatible migrations into compatible `prepare` and forward
  `commit` phases.
- [x] Guarantee rollback only until durable trial acceptance.
- [x] Keep reverse migrations and whole-state update snapshots out of scope.
- [x] Block a failed digest locally after automatic rollback.
- [x] Keep restart user-controlled after automatic background staging.
- [x] Reconcile accepted lifecycle decisions into [Forward-Only Migrations and Trial-Bounded Rollback](boot-system-lifecycle.md) and [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md).

#### A2 — release and trust lifecycle

- [x] Define withdrawal and offline-cached emergency revocation semantics.
- [x] Select Microsoft-signed ShapeBit shim with factory PK/KEK preserved.
- [x] Separate development and production trust domains.

#### A3 — storage and recovery lifecycle

- [x] Confirm `@root`, `@state`, `@homes`, and `@recovery` and the inactive
  home-container boundary.
- [x] Select Btrfs inside per-user LUKS2 home containers.
- [x] Select guaranteed home minimums, shared burst capacity, and dynamically
  calculated protected reserves.
- [x] Specify reset preservation and controlled home rebinding.
- [x] Select a minimal recovery UKI on the ESP and equivalent USB media.
- [x] Select the offline-first TUI and rotating `recovery-a`/`recovery-b` slots.
- [x] Define conservative export-first behavior after Btrfs corruption.
- [x] Define rollback, repair, reset, remove-user, and two erase outcomes.
- [x] Accept [Btrfs for Persistent System State](base-system.md), [Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md), and [Independent Recovery Environment](diagnostics-recovery.md).

#### A4 — installer contract

- [x] Select exclusive whole-disk installation for the initial profile.

#### A5 — product and platform contracts

- [x] Define the QEMU profile and versioned physical-hardware evidence labels.
- [x] Define official Linux x86-64/KVM development scope with Fedora canonical.
- [x] Define the initial physical threat boundary and suspend authentication.
- [x] Select Flathub plus a first-party-only ShapeBit Flatpak repository.
- [x] Define per-user Flatpak ownership, updates, permissions, and storage.
- [x] Select a Wayland-only initial application catalog with X11-only entries
  hidden from the normal UI.
- [x] Define unsandboxed per-user AppImage discovery, import, and update policy.
- [x] Permit ordinary native AppImage MIME, URI, default-app, autostart, and
  user-service behavior under the broad-permission warning.
- [x] Define compositor, shell, greeter, lock, and authorization boundaries.
- [x] Define administrator, root-login, and SSH policy.
- [x] Define developer-mode security and trust-domain guarantees.
- [x] Define mixed-monitor scaling, HDR, VRR, docking, and capture behavior.
- [x] Define system power, suspend, hibernation, thermal, and charging policy.
- [x] Select PipeWire and WirePlumber and define media privacy boundaries.
- [x] Define screen-share, remote-input, and notification privacy policy.
- [x] Define network-profile ownership and device-wide VPN behavior.
- [x] Select NetworkManager with `systemd-resolved`, split DNS, and strict
  per-profile DNS-over-TLS.
- [x] Define firewall defaults, SSH network scope, MAC randomization, and local
  discovery policy.
- [x] Defer dedicated captive-portal support from the initial release.
- [x] Select SFTP through configured SSH plus optional per-user SMB 3 sharing.
- [x] Select default-minimal, user-disableable telemetry and consent-only
  detailed reports.

### Delivery roadmap

Tasks below are implementation outcomes. They remain unchecked until verified,
even when supporting scripts or documentation already exist.

#### M0 — architecture baseline

- [x] Select Fedora bootc.
- [x] Select Dioxus for the installer frontend.
- [x] Select per-user encrypted homes.
- [x] Select TPM2-unlocked system-volume encryption.
- [ ] Complete A1-A5 and review all proposed architecture sections.

#### M1 — bootable secure console prototype

- [ ] Build and lint the bootc container image reproducibly.
- [ ] Create a VM disk and boot it through UEFI to a TTY.
- [ ] Add signed UKI boot under OVMF Secure Boot.
- [ ] Add sealed-deployment verification.
- [ ] Add system LUKS2 with TPM2 automatic unlock and recovery key.
- [ ] Add Btrfs persistent-state layout and zram.
- [ ] Add one `systemd-homed` user with one-password TTY login.
- [ ] Record positive, rejection, recovery, and power-loss evidence.

#### M2 — update and rollback prototype

- [ ] Produce signed releases A and B from immutable artifact sets.
- [ ] Stage B while preserving A.
- [ ] Authorize TPM2 unlock for both pending and rollback UKIs.
- [ ] Accept a successful trial boot.
- [ ] Automatically return to A after failed trial boots.
- [ ] Stage B through compatible recovery when A's updater is outside B's
  accepted updater range.
- [ ] Exercise migration interruption, pre-acceptance rollback, and
  post-acceptance commit resumption.
- [ ] Produce a diagnostic report for every transition.

#### M3 — installer backend and protocol

- [ ] Implement the shared protocol and secret-free installation plan.
- [ ] Implement validation, dry run, events, and mock operations.
- [ ] Implement the privileged backend against a virtual disk.
- [ ] Install the M1 system and verify first boot.
- [ ] Verify recovery keys and interruption reporting.

#### M4 — Dioxus installer

- [ ] Connect the UI to the mock backend.
- [ ] Complete accessibility and destructive-action UX review.
- [ ] Connect the UI to the real backend.
- [ ] Install to a virtual disk and boot to a TTY.

#### M5 — automated release pipeline

- [ ] Build RPMs and bootc images in CI.
- [ ] Generate SBOMs, manifests, attestations, and test reports.
- [ ] Integrate restricted boot and policy signing.
- [ ] Automate boot, update, rollback, recovery, and rejection tests.
- [ ] Build non-production developer/nightly artifacts without promotion rights.
- [ ] Produce a production candidate and manually promote the identical artifact
  from testing to stable.

#### M6 — desktop platform

- [ ] Implement versioned platform services.
- [ ] Implement the nested Smithay compositor.
- [ ] Add the restartable shell, launcher, panel, notifications, and settings.
- [ ] Add the separate PAM greeter, trusted lock UI, and authorization agent.
- [ ] Add fractional scaling, HDR color management, SDR capture, and VRR.
- [ ] Add display layout, automatic docked mode, and the system power service.
- [ ] Add PipeWire/WirePlumber policy, media portals, and privacy indicators.
- [ ] Add user/system network profiles, VPN policy, DNS, and firewall controls.
- [ ] Add per-user Flatpak management and the two official remotes.
- [ ] Add AppImage discovery, import, warning, update, and removal flows.
- [ ] Boot a complete session in a VM.

#### M7 — hardware validation and recovery

- [ ] Validate the supported hardware matrix.
- [ ] Validate production key rotation and revocation.
- [ ] Implement and validate TPM2-backed anti-rollback.
- [ ] Harden recovery, reset, backup export, and installer behavior.
- [ ] Pass storage corruption, low-space, and power-loss testing.

#### M8 — developer preview

- [ ] The team can install, update, recover, and use ShapeBit OS daily.

#### M9 — public alpha

- [ ] No persistent device retains prototype trust enrollment.
- [ ] Stable rollout, diagnostics, recovery, and device erase are operational.
- [ ] The published hardware scope and security claims match verified evidence.

### Explicitly deferred work

- blanket support claims for arbitrary generic PCs;
- custom firmware PK/KEK enrollment and owner-managed Secure Boot keys;
- same-disk dual boot, partition shrinking, and manual partitioning;
- custom ShapeBit hardware;
- hibernation and encrypted resume;
- fast graphical user switching;
- native HDR screenshots and recordings;
- dedicated captive-portal detection and login UI;
- per-user and per-application VPN network namespaces;
- system-wide DNS-over-HTTPS;
- public host-extension ecosystem;
- XWayland;
- offline update bundles;
- complete cloud backup;
- polished consumer onboarding and application ecosystem.
