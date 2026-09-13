# System Lifecycle

## Installer

See [Installer](installer.md).

## Boot Trust

The system boots through:

UEFI Secure Boot
    ↓
Microsoft-signed ShapeBit shim
    ↓
signed systemd-boot
    ↓
signed ShapeBit UKI
    ↓
verified system deployment

The UKI contains the kernel, initramfs, kernel command line, and TPM PCR policy. The system does not maintain separate unsigned kernel or initramfs files on the ESP.

The ESP is unencrypted and contains no private keys or user data.

Production systems retain the manufacturer's normal UEFI PK/KEK configuration. Custom firmware-key enrollment is not required.

### Development

OVMF
→ ShapeBit Dev CA
→ dev-signed UKI

## Release Identity

Every ShapeBit release is identified by a signed immutable release manifest.

The manifest binds the exact artifacts that belong to one release:

version;
architecture;
OCI image digest;
signed UKI digest;
composefs root digest;
minimum compatible updater and recovery versions.
release manifest
├── OCI image
├── composefs root
└── signed UKI

Channels and tags such as stable or testing are discovery pointers only. They do not identify a release.

The updater accepts a deployment only when all referenced digests match the downloaded and locally prepared artifacts.

The manifest is strict and signed. Unknown or malformed fields are rejected.

Mutable data such as rollout state, mirrors, withdrawal, and revocation is stored separately and refers to the immutable release by digest.

### Artifact Binding

The release binds the system image and boot artifact through the composefs root digest:

OCI image
    ↓
composefs root
    ↓
rootfs digest
    ↓
signed UKI

The UKI contains the expected rootfs digest.

During boot, initrd:

obtains the expected digest from the signed UKI;
selects exactly one matching local deployment;
requires active fs-verity verification;
unlocks and switches to that deployment.

A missing, malformed, or mismatched identity is a hard boot failure.

The release manifest binds the final UKI digest, OCI image digest, and rootfs digest together so independently valid artifacts from different releases cannot be mixed.

## Release Channels

ShapeBit defines:

stable      production releases
testing     production-signed candidates
developer   local development builds

Only unchanged production-signed candidates move from testing to stable.

Developer builds cannot be promoted directly into the production trust domain.

Stable promotion is an explicit release decision rather than an automatic consequence of passing CI.

## Release Withdrawal and Revocation

ShapeBit distinguishes:

### Withdrawn

A release is no longer offered because of a quality problem.

Existing accepted installations may continue running while a replacement release is prepared.

### Revoked

A release must no longer be selected for another boot because continuing to boot it is unsafe.

A revoked pending or trial deployment is abandoned.

If no known-safe normal deployment exists, ShapeBit enters recovery.

Revocation metadata is signed and cached locally so previously learned revocations continue to apply offline.

## System Updates

### Update Pipeline

The system downloads and verifies updates in the background.

A system update proceeds as:

download
   ↓
verify manifest and artifacts
   ↓
stage deployment
   ↓
stage signed UKI
   ↓
user restart
   ↓
trial boot
   ↓
health verification
   ├── fail → rollback
   └── pass → accept

The OS never makes a downloaded release bootable until its signed manifest, artifact identities, UKI, rootfs binding, and TPM authorization have been validated.

Updates do not force the user to terminate an active desktop session.

### Trial Boot, Rollback, and Health

A newly staged deployment starts as pending.

Booting it changes it to trial.

ShapeBit uses systemd Automatic Boot Assessment for attempt counting and boot selection rather than maintaining a second authoritative boot database.

The default limit is two trial attempts.

accepted
   ↓
pending
   ↓
trial
 ┌─┴────────────┐
 ↓              ↓
accepted       failed
                ↓
             rollback

The previous accepted deployment remains available until the new deployment is durably accepted.

A deterministic integrity or structural failure causes immediate rollback.

An ambiguous failure consumes a trial attempt. When attempts are exhausted, systemd-boot selects the previous accepted deployment.

A failed release is locally blocked from automatic restaging until another release supersedes it or recovery explicitly retries it.

#### Boot Health

A trial deployment is accepted only when ShapeBit verifies:

expected release and deployment identity;
required system storage;
critical platform services;
functioning network stack;
usable graphical login environment.

Internet connectivity and user login are not required.

All mandatory checks must succeed and remain healthy for a short continuous observation period before the deployment is blessed.

Exact units, service lists, timeouts, retry periods, and diagnostic codes are implementation policy rather than architecture.

## Signing

Production and development builds use separate trust domains.

ShapeBit v1 uses a small production hierarchy:

offline root
├── release signing
├── boot + PCR signing
└── repository signing

The root key delegates operational keys and is not used for ordinary release signing.

Production private keys must:

remain outside Git and OCI images;
never be installed on user systems;
never be exposed to ordinary CI jobs;
use hardware-backed or equivalently protected storage.

Development uses clearly distinct disposable keys.

More granular role separation and threshold root signing may be introduced as the project and release organization grow.

### Signing Process

CI produces unsigned release artifacts and their digests.

Production signing requires explicit authorization.

The release is signed only after the final OCI image, rootfs identity, UKI, and metadata are fixed.

Signing operations produce an immutable audit record identifying the inputs and outputs.
