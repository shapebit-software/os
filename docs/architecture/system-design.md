# ShapeBit OS System Design

**Document type:** Living system design and delivery tracker

**Last updated:** 2026-08-09

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

The initial audience is technical users, developers, and testers using x86-64
UEFI Secure Boot and TPM2 laptops or the controlled QEMU/OVMF/software-TPM
profile. ShapeBit does not define one reference laptop and does not claim that
all modern PCs are supported.

Physical evidence is release-, firmware-, and configuration-specific:

- **Officially-tested** means the ShapeBit team passed the complete mandatory
  product suite and published the capability matrix;
- **Community-tested** means a community report supplied sufficient positive
  evidence without the official suite;
- **Unknown** means there is no sufficient current positive evidence and does
  not by itself mean incompatible.

Developer and nightly artifacts may publish after the mandatory QEMU suite.
Stable and public-alpha releases require at least one `Officially-tested`
laptop for the exact release. ShapeBit initially validates market-available
laptops and defers custom hardware.

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

The production compatibility and trust chain begins as follows:

```text
UEFI Secure Boot
-> Microsoft 3rd Party UEFI CA
-> Microsoft-signed ShapeBit shim
-> ShapeBit-signed systemd-boot
-> signed UKI carrying the sealed-deployment identity
-> required fs-verity verification
-> PCR 7 plus signed PCR 11 authorization
-> TPM2 unlocks the system LUKS2 volume
-> login surface
```

PCR 7 is directly bound to Secure Boot policy. PCR 11 uses signed expected
measurements so ordinary approved UKI updates do not require sealing to one
fixed value. PCR 0 and PCR 2 are excluded initially because normal firmware and
hardware changes would cause unnecessary recovery. The supported path does not
use MOK, so shim alone does not add PCR 14 to the policy.

Production boot signing, PCR-policy signing, release-manifest signing, and
device recovery use separate keys. Production private keys never enter Git,
OCI layers, installed disks, logs, or ordinary CI workers. Development uses a
separate development shim and locally generated disposable keys.

Production preserves factory PK and KEK databases. ShapeBit maintains its own
reviewed shim and uses Microsoft signing to enter the factory trust chain.
Fedora's shim is limited to disposable experiments.

ShapeBit protects powered-off devices against offline data access and
unauthorized boot or deployment modification, including temporary unattended
physical access. It does not claim protection against compromised firmware,
malicious hardware, advanced laboratory attacks, an already unlocked session,
or arbitrary privileged code already running in an authorized boot.

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

### 7.2 Accepted disk layout

```text
GPT
├── EFI System Partition
│   ├── Microsoft-signed ShapeBit shim
│   ├── signed systemd-boot and signed UKIs
│   └── minimal signed recovery UKI
└── system LUKS2
    └── Btrfs physical root
        ├── bootc-managed deployments and /usr
        ├── @root
        ├── @state
        ├── @homes
        │   └── systemd-homed container files
        └── @recovery
```

The initial layout uses only these four lowercase, single-word structural
subvolumes. It does not create one subvolume per service and does not reserve an
`@snapshots` subvolume. Snapshot and migration-generation policy remains open.

The system LUKS2 volume protects device state and inactive home-container files
against physical disk access. Each human home remains a separate LUKS2
container with independent credentials and Btrfs inside. Homes share a dynamic
capacity pool with a guaranteed minimum per home, equal default allocation
weight, owner-defined limits, and a shared burst pool. A new account may be
created only when its minimum can be guaranteed without revoking used capacity
from another home.

The protected system reserve is calculated from emergency, transaction/log,
pending deployment, retained rollback, migration-workspace, and Btrfs-metadata
needs rather than one fixed percentage. Automatic cleanup touches only data
explicitly declared rebuildable; it never deletes user data, retained boot
states, recovery assets, or transaction-critical state. Exact numerical
formulas and thresholds remain open.

The initial installer owns and erases one explicitly selected physical disk. It
does not shrink partitions, install alongside another system, or offer manual
partitioning. Other physical disks remain untouched.

Zram is the default swap. Plaintext disk-backed swap is never supported.
Hibernation remains out of scope until encrypted resume and deployment
compatibility have a separate accepted design.

### 7.3 Persistent-data contract

The initial system does not perform incompatible automatic migrations of
persistent host data. Every persistent host path is either `preserved` or
`disposable`. Preserved data must remain readable by N and N-1 throughout the
rollback window. Disposable data may be deleted and recreated without losing
user data or required device configuration. An undeclared path blocks stable
release.

A host service must be stateless, own only disposable state, or pass a tested
`N -> N+1 -> rollback N` cycle for its preserved state. Otherwise it is pinned,
excluded, redesigned, or receives a compatible backport. Flatpak application
data is outside the host rollback contract. General reverse migrations, bridge
releases, and rollback barriers are deferred until a concrete incompatible
state change justifies a new design.

Snapshot ownership, retention, and migration-generation policy is explicitly
deferred. No snapshot is treated as a backup.

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

ShapeBit exposes one **Require authentication after suspend** setting, enabled
by default. When enabled, suspend locks both the session and the active
`systemd-homed` home, removes the home key from memory, and uses one
authentication interaction to restore both. When disabled, resume returns
directly to the session and the UI warns that the session and home key remain
available in memory. Full physical-access protection is claimed only for a
powered-off device.

The first human account is an administrator, but all desktop processes remain
unprivileged. Narrow root services expose versioned D-Bus operations and Polkit
authorization. The trusted authorization agent may cache authentication for a
short period, but every later operation still receives a **Yes**/**No**
confirmation. Direct root login is disabled; graphical Polkit and terminal
`sudo` caches remain separate.

The greeter, each user compositor, the shell, lock UI, and authorization agent
are separate processes. ShapeBit allows one logged-in graphical session at a
time, while SSH sessions may coexist and keep that user's home active. SSH is
disabled by default. Key login is sufficient for an already active home; an
inactive home requires the key followed by the normal PAM password. Password-
only SSH, remote Recovery Kit use, and direct root SSH are disabled.

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

The trial limit is two attempts. A deterministic hard failure rolls back
immediately; an ambiguous interruption, power loss, or shutdown before durable
acceptance may use the one remaining attempt. A declared bounded multi-stage
restart does not consume another attempt. Two unsuccessful attempts select the
previous accepted deployment.

A deployment is accepted automatically after mandatory identity, storage,
critical-service, and graphical-login checks followed by two minutes of
continuous healthy operation. Login and Internet access are not required.
The network-management stack must start, but association, DHCP, DNS, and
external connectivity are not gates.

ShapeBit uses systemd Automatic Boot Assessment. A new UKI filename carries two
attempts; `systemd-boot` decrements the counter before boot. ShapeBit health
units gate `boot-complete.target`, and `systemd-bless-boot` removes the counter
only after all checks and the observation period succeed. A hard failure may
mark the entry bad immediately. Diagnostic reports live in `@state` but are not
a second boot-selection authority.

After automatic rollback, the exact failed digest is locally blocked from
automatic restaging. A different digest proceeds normally, while recovery may
retry the failed digest only after informed user action.

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

ShapeBit automatically checks, downloads, verifies, and stages updates over any
working network connection without distinguishing metered networks. Downloads
are resumable. Applying a staged deployment waits for a user-chosen restart;
the updater never terminates an active session merely to update.

### 9.3 Release service

Accepted stable releases are offered in deterministic cohorts. Rollout changes
who discovers a manifest; it never changes that manifest or rebuilds its
artifacts. A release service can suspend discovery, block a digest, or publish a
superseding release. Repointing a channel does not remediate devices already
running a withdrawn release.

Rollout pauses automatically after a sufficient sample crosses configured
failure thresholds, but only an authorized human may resume it. Exact wave
sizes, sample sizes, and thresholds remain release-policy parameters.

Minimal operational telemetry is enabled by default but may be disabled
completely without affecting updates. It contains the digest, accepted or
rolled-back result, broad failure stage, attempts consumed, and a random token
scoped to one release. It contains no stable device identifier or user content,
and the service does not retain source IP addresses. Detailed logs and hardware
information require separate consent and a user-visible preview.

`withdrawn` stops discovery, cancels an unbooted staged copy when learned, and
locally blocks that digest without removing an already accepted deployment.
`revoked` is reserved for releases unsafe to boot. It uses a separate offline
emergency key and two-person approval, cancels matching pending/trial states,
selects a safe deployment for the next boot, and enters recovery if none exists.
It does not terminate the active session. Devices enforce the last cached signed
revocation list offline; the list does not expire in a way that prevents boot,
and ShapeBit cannot enforce revocations published after permanent disconnect.

## 10. Recovery operations

These operations are intentionally distinct:

| Operation | System deployment | Device state | User homes |
|---|---|---|---|
| Roll back | select previous accepted deployment | preserve | preserve |
| Repair system | restore current system and boot artifacts | preserve | preserve |
| Reset system | restore clean system | clear configuration and ordinary state | preserve encrypted containers for controlled rebinding |
| Remove user | unchanged | remove that account inventory | erase only that user's home |
| Erase device | optionally reinstall latest compatible non-revoked stable | erase | erase all |

The recovery environment is a separately versioned, minimal signed UKI on the
ESP, outside normal deployment rotation. It starts without the system LUKS2 or
Btrfs, mounts data read-only by default, uses the device recovery key when TPM2
unlock is unavailable, and requires a user's own credential to access that
user's home. The same signed environment is distributable as USB recovery
media.

Reset generates a new local home-record signing key and never preserves the old
private key or bindings. A minimal non-private inventory links old public
identity, account/container identifiers, and role to the recovery flow. Each
user proves possession of their own password or home recovery key to rebind;
the device recovery key cannot unlock a home.

Recovery initially uses an offline-first local/serial TUI. The ESP rotates two
independent recovery slots, `recovery-a` and `recovery-b`, by writing and
verifying the inactive slot before selection. Network reinstall is preferred,
signed USB media is the fallback, and no large factory image is retained
locally. Erase offers cryptographic erase with optional verified hardware
sanitize and supports both reinstall and no-reinstall outcomes.

After suspected Btrfs corruption, recovery is read-only and export-first. It
never runs destructive `btrfs check --repair` automatically, prefers
non-mutating export to other physical media, and favors a new filesystem or
disk replacement over trusting an in-place repair.

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

The first destructive storage contract uses an entire explicitly selected
physical disk. Same-disk dual boot, filesystem shrinking, and manual
partitioning are not valid initial installation plans.

## 12. Application and desktop platform

| Software | Supported delivery mechanism |
|---|---|
| sandboxed user application | per-user Flatpak |
| portable native application | per-user AppImage with explicit trust warning |
| essential system application | immutable OS image |
| web application | browser or PWA |
| developer tool | Distrobox/Podman |
| host service | system image |
| driver or kernel module | system image or future controlled extension |

Arbitrary host `dnf install` is not a supported product workflow. Public host
extensions are deferred; future options include image variants and signed
system extensions.

The normal application catalog combines Flathub for third-party software with a
separate ShapeBit repository for first-party applications and ShapeBit-owned
integration artifacts. An integration may contain scripts, manifests, metadata,
and sandbox configuration but never third-party binaries; it uses a ShapeBit ID
and downloads the payload directly from the identified producer or distributor.
Recommendations are selected manually, retain accurate source labels, and are
not chosen through paid promotion. Other remotes are advanced per-user
extensions outside ShapeBit application support.

Each user owns a separate Flatpak installation inside their encrypted home.
Applications, runtimes, caches, and data consume that user's capacity and update
only while the home is active. Safe updates are automatic, but a static
permission expansion requires user approval. ShapeBit provides no automatic
application rollback. The OS image contains only the applications necessary to
operate the system; no Flathub application is preinstalled, and first-login
onboarding offers manually curated downloads when online.

The immutable graphical set is ShapeBit Settings, Files, Apps, Diagnostics,
Terminal, Help, Text, and Calculator. Terminal is hidden outside developer mode.
Full document and media applications remain per-user Flatpaks. First-login
onboarding offers Chrome, Chromium, Firefox, Brave, and GNOME Web without a
preselected default. Chrome downloads Google binaries through `extra-data`;
Chromium downloads Fedora-signed RPMs through a ShapeBit integration.

The initial application platform is Wayland-only. The normal store hides
X11-only applications, and an update that would turn a working Flatpak into an
X11-only application is not activated. Developer tooling may expose unsupported
catalog entries. XWayland is deferred.

AppImage is a separate per-user native-executable path, not a repository in the
store. ShapeBit offers **Run once** or **Add to Apps**, manages imported files in
the user's home, and warns that every AppImage runs unsandboxed with all rights
of that user. It does not classify AppImage signatures. Every manager-driven
update requires confirmation and uses download-then-atomic-replacement. The
manager watches `Downloads`, `Desktop`, and user-selected directories, alerts
once per new hash, and never executes payload code while reading metadata.
ShapeBit adds no AppImage-specific restriction to MIME and URI handlers,
default applications, autostart, or user services; those capabilities are part
of the broad native-executable warning.

Developer mode uses rootless Podman and Distrobox rather than Toolbox. New
containers initially default to the Fedora Toolbox image matching the current
ShapeBit base. Distrobox is not a security sandbox. A validated ShapeBit
development image may become the later first choice while Fedora remains a
supported reference.

The desktop uses Rust, Smithay, Wayland, systemd user services, D-Bus,
PipeWire, portals, libinput, Mesa, DRM, and KMS. A minimal compositor owns
Wayland, input, outputs, and lock state. One restartable shell contains the
panel, launcher, notifications, and primary desktop UI. Separate trusted
processes own locking and authorization. A shell failure preserves applications;
a compositor failure ends the damaged graphical session, returns to the
independent greeter, and records diagnostics. ShapeBit applications provide
autosave where possible, but arbitrary process state is not recoverable.

Per-output fractional scaling, remembered layouts, HDR, independent SDR/HDR
color transforms, and fullscreen VRR are initial requirements. HDR is enabled
manually per monitor. Screenshots, recordings, and sharing are tone-mapped to
SDR initially. With the lid open, a new monitor extends the desktop. With the
lid closed, an active external monitor automatically becomes the docked output;
disconnecting the last external output requests suspend.

A system power service owns lid, battery, profile, suspend, and thermal policy
independently of the shell. The initial profiles are Balanced, Power Saver, and
hardware-dependent Performance. Firmware and kernel drivers own fans and
thermal thresholds. Suspend-to-RAM is supported; hibernation is not. A failed
lid-close suspend causes controlled shutdown. A hardware-supported system-wide
charge limit is changeable by an active local administrator with confirmation
but without a password.

PipeWire transports audio and capture streams, while WirePlumber owns per-user
device and routing policy. Flatpak microphone and camera access uses portals and
visible indicators. Direct-device enforcement against unsandboxed AppImage is
best effort. Screen capture and remote input remain compositor-mediated for all
applications, require per-session consent, stop on lock, and cannot control
trusted surfaces. Whole-monitor sharing suppresses notification banners by
default. The lock screen shows no application notifications, and only an
allowlisted root ShapeBit service may issue a critical notification.

## 13. Networking and connectivity

NetworkManager owns device-wide connectivity. Ethernet and administrator-
approved system profiles can operate before login. New Wi-Fi and VPN profiles
belong to their creating user by default and keep credentials inside that
encrypted home. Their connections still carry device-wide traffic while active
and end after the owner's final session. Wi-Fi uses a stable randomized MAC per
profile unless explicitly overridden.

Initial VPNs change routing and DNS for the whole device. User VPNs require an
active local graphical owner but no administrator password; system VPNs require
administrator authorization. An optional per-profile kill switch blocks all
non-tunnel traffic during an unexpected outage, with local-LAN access as an
explicit exception.

NetworkManager integrates with `systemd-resolved` for per-link and split DNS.
VPN DNS never silently falls back to an ordinary link. Strict DNS-over-TLS is a
per-profile option with no plaintext fallback; system-wide DoH is deferred.

The firewall denies unsolicited inbound traffic. SSH exposure is enabled by an
administrator per saved network profile rather than globally. Local mDNS
discovery is off for a new profile and may be enabled by its owner without
publishing ShapeBit services; LLMNR stays off. Dedicated captive-portal support
is outside the initial release. Inbound file-sharing scope remains undecided.

## 14. Development, CI, and release flow

```text
fast:        edit -> build -> nested/local test
integration: edit -> RPM -> bootc image -> QEMU
release:     merge -> CI -> artifacts -> controlled signing -> tests -> promotion
```

Stable systems are not modified manually. Development uses containers, VMs,
temporary overlays, or a developer-channel image.

The official developer host class is Linux x86-64 with KVM. Fedora is the
canonical host and required CI environment; another Linux distribution may use
the same flow after passing capability checks. macOS, Windows, WSL, ARM64, and
non-KVM hosts are initially outside official scope.

Development and production are separate trust domains. One development command
prepares disposable local keys, a development shim, OVMF variables, software
TPM state, signed artifacts, the VM, and a test report. Production uses the
Microsoft-signed ShapeBit shim and restricted signing services; no production
shim may trust a development key.

Using the ShapeBit developer channel as the team's primary daily host is a
distant dogfooding goal. Fedora permanently remains an independent bootstrap,
CI, and fallback path. Both hosts will use the same pinned SDK container.

The target pipeline is:

```text
lint -> unit tests -> RPMs -> image -> bootc lint -> security scan
-> controlled signing -> QEMU boot -> Secure Boot and TPM2 tests
-> service and desktop tests -> update and rollback tests -> publish
```

Stable must be the exact digest and signed artifact set that passed testing.

`developer` uses local keys and `nightly` uses a central non-production key.
Neither is directly promotable. A selected revision produces a separately
tested and production-signed candidate for `testing`; only that exact candidate
may be manually promoted to `stable`. The normal UI exposes only stable.
Release cadence and minimum testing duration remain undecided.

## 15. Architecture work queue

This is the current planning queue. Complete it before expanding implementation
scope beyond disposable prototypes.

### Remaining decision backlog

This is the canonical ordered list of unresolved architecture work. The A0-A5
sections below retain completed decision history and do not duplicate open
items. Deferred features in section 17 are not counted here.

#### P0 — product behavior that can be decided now

- [x] **D01 — Inbound file sharing:** use SFTP through configured SSH and
  optional per-user SMB 3 sharing as defined by ADR-0022.
- [x] **D02 — Authorization cache:** use a fixed, non-renewable five-minute
  Polkit authentication cache as defined by ADR-0018.
- [x] **D03 — System application set:** use the exact offline desktop core,
  browser onboarding, integration wrappers, and Distrobox environment defined
  by ADR-0023.
- [x] **D04 — Application recommendations:** use sole-curator approval,
  event-driven review without a fixed cadence, and the signed canonical list
  defined by ADR-0024.
- [x] **D05 — Enterprise network credentials:** use the bounded 802.1X, VPN,
  software-certificate, safe-import, and strict server-identity set defined by
  ADR-0025.
- [x] **D06 — Boot health details:** use the five parallel controls, exact
  timeouts, bounded observation, and failure transitions defined by ADR-0026.
- [ ] **D07 — Staged-restart UX:** define notification and reminder cadence for
  an installed update waiting for a user-controlled restart.

#### P1 — platform, storage, and release contracts

- [ ] **D08 — Capacity policy:** define reserve formulas, home quotas, burst
  behavior, low-space thresholds, and warnings.
- [ ] **D09 — Snapshot policy:** define snapshot ownership, scope, retention,
  deletion, and the relationship to rollback and backup.
- [ ] **D10 — Platform-service API:** define versioning, compatibility, caller
  identity, authorization, errors, and lifecycle for system D-Bus services.
- [ ] **D11 — Diagnostics:** define the complete report schema, redaction,
  preview, consent, retention, and export rules.
- [ ] **D12 — Unsupported host modifications:** define detection, diagnostics,
  recovery, and support status when protected host state is modified.
- [ ] **D13 — Test evidence schemas:** define exact mandatory QEMU and physical-
  hardware test records and pass criteria.
- [ ] **D14 — Release timing:** define stable cadence, minimum testing duration,
  and the emergency-release exception process.

#### P1 — installer contract

- [ ] **D15 — Installation protocol schemas:** define versioned
  `InstallationPlan`, capability, event, and error structures.
- [ ] **D16 — Secret enrollment:** define the secret channel, credential
  ownership, exposure boundaries, cancellation, and memory lifetime.
- [ ] **D17 — Installer transaction lifecycle:** define phases, durable state,
  cancellation points, retry, resume, and interruption behavior.
- [ ] **D18 — Disk identity and confirmation:** define stable device identity,
  replacement detection, final destructive confirmation, and stale-plan rules.
- [ ] **D19 — Recovery Kit flow:** define presentation, verification,
  confirmation, printing/export, and secret-lifetime UX.
- [ ] **D20 — Installer decision mapping:** map every installation operation to
  its authoritative ADR. This is documentation closure rather than a new
  product decision.

#### P1 — release trust and anti-rollback

- [ ] **D21 — Release manifest:** define the canonical schema, serialization,
  signature envelope, identifiers, and compatibility fields.
- [ ] **D22 — Artifact binding:** define the verifiable binding among the OCI
  digest, sealed deployment, UKI, release manifest, and PCR policy.
- [ ] **D23 — Signing operations:** define production ownership, HSM roles,
  authorization, rotation, audit, and compromise response for every key.
- [ ] **D24 — Strong anti-rollback:** create the TPM2 NV security-epoch ADR,
  including transitions, rollback window, recovery, and failure behavior.
- [ ] **D25 — Prototype trust migration:** define how early TPM enrollments are
  detected, invalidated, and migrated without preserving an old unlock path.

#### Acceptance gates

- [ ] **G01 — ADR-0002:** accept, revise, or reject filesystem ownership after
  the required update-and-rollback evidence exists.
- [ ] **G02 — ADR-0006:** accept or revise signed release identity after D21-D23.
- [ ] **G03 — ADR-0013:** accept or revise boot trust after D22-D25 and the
  required QEMU and physical-hardware evidence.

### A0 — documentation structure

- [x] Establish ADRs as the authority for durable decisions.
- [x] Add an ADR index and decision ownership map.
- [x] Remove duplicated architecture sources.
- [x] Consolidate system design, status, roadmap, and task tracking here.

### A1 — deployment lifecycle

- [x] Select systemd-boot counting and blessing as boot-state authority.
- [x] Define success, failure, intentional-shutdown, and power-loss rules.
- [x] Select two trial attempts and immediate rollback for hard failures.
- [x] Require mandatory checks plus two minutes of healthy observation.
- [x] Replace automatic migrations with `preserved` and `disposable` state.
- [x] Require tested N/N-1 compatibility for preserved host state.
- [x] Defer bridge releases, reverse migrations, and rollback barriers.
- [x] Block a failed digest locally after automatic rollback.
- [x] Keep restart user-controlled after automatic background staging.
- [x] Reconcile accepted lifecycle decisions into ADR-0004 and ADR-0007.

### A2 — release and trust lifecycle

- [x] Define withdrawal and offline-cached emergency revocation semantics.
- [x] Select Microsoft-signed ShapeBit shim with factory PK/KEK preserved.
- [x] Separate development and production trust domains.

### A3 — storage and recovery lifecycle

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
- [x] Accept ADR-0003, ADR-0005, and ADR-0008.

### A4 — installer contract

- [x] Select exclusive whole-disk installation for the initial profile.

### A5 — product and platform contracts

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

## 16. Delivery roadmap

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
- [ ] Exercise preserved-state N/N-1 rollback and disposable-state recreation.
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
- [ ] Build non-production developer/nightly artifacts without promotion rights.
- [ ] Produce a production candidate and manually promote the identical artifact
  from testing to stable.

### M6 — desktop platform

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

### M7 — hardware validation and recovery

- [ ] Validate the supported hardware matrix.
- [ ] Validate production key rotation and revocation.
- [ ] Implement and validate TPM2-backed anti-rollback.
- [ ] Harden recovery, reset, backup export, and installer behavior.
- [ ] Pass storage corruption, low-space, and power-loss testing.

### M8 — developer preview

- [ ] The team can install, update, recover, and use ShapeBit OS daily.

### M9 — public alpha

- [ ] No persistent device retains prototype trust enrollment.
- [ ] Stable rollout, diagnostics, recovery, and device erase are operational.
- [ ] The published hardware scope and security claims match verified evidence.

## 17. Explicitly deferred work

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
