# System Lifecycle

This page explains how the OS establishes trust when it boots, how a
release is identified and signed, how updates are delivered and verified,
and what happens when a release turns out to be bad.

## Signing

Production and development builds live in two completely separate trust
domains. A development key can never sign anything production will accept,
and vice versa.

The OS v1 uses a small production key hierarchy:

```
offline root
 ├── release signing
 ├── boot + PCR signing
 └── repository signing
```

The root key only exists to delegate these operational keys — it is not
used to sign ordinary releases.

Production private keys must:

- never be stored in Git or baked into OCI images
- never be installed on a user's system
- never be exposed to ordinary CI jobs
- live in hardware-backed (or equivalently protected) storage

Development uses its own, clearly separate, disposable keys.

As the project and its release process grow, finer-grained role separation
and threshold signing for the root key may be introduced.

### Signing Process

1. CI produces unsigned release artifacts and their digests.
2. Production signing requires explicit human authorization — it never
   happens automatically.
3. A release is only signed once its final OCI image, rootfs identity,
   UKI, and metadata are all fixed.
4. Every signing operation leaves an immutable audit record of exactly
   what went in and what came out.

## Boot Trust

A production system boots through an unbroken chain of signatures:

```
UEFI Secure Boot
  → Microsoft-signed ShapeBit shim
  → signed systemd-boot
  → signed ShapeBit UKI
  → verified system deployment
```

Each step only proceeds once the previous one has been verified.

A few things worth knowing about this chain:

- The UKI bundles the kernel, initramfs, kernel command line, and TPM PCR
  policy into a single signed file. There is no separate, unsigned kernel
  or initramfs sitting on the ESP.
- The ESP itself is unencrypted and holds no private keys or user data.
- Production systems keep the manufacturer's normal UEFI PK/KEK setup —
  ShapeBit does not require enrolling custom firmware keys.

### Development

Development machines boot through a separate, disposable chain instead:

```
OVMF → ShapeBit Dev CA → dev-signed UKI
```

## Release Identity

Every the OS release is identified by one signed, immutable **release
manifest**. The manifest ties together the exact artifacts that make up
that release:

- version
- architecture
- OCI image digest
- signed UKI digest
- composefs root digest
- minimum compatible updater and recovery versions

```
release manifest
 ├── OCI image
 ├── composefs root
 └── signed UKI
```

A few rules follow from this:

- Channels and tags like `stable` or `testing` are just discovery
  pointers — they help you *find* a release, they don't *identify* one.
- The updater only accepts a deployment once every digest it references
  matches what was actually downloaded and prepared locally.
- The manifest format is strict: unknown or malformed fields are
  rejected outright.
- Mutable data — rollout state, mirrors, withdrawal, revocation — is
  stored separately and simply refers back to the immutable release by
  digest.

### Artifact Binding

The composefs root digest is what ties the system image and the boot
artifact together into one verified unit:

```
OCI image
  → composefs root
  → rootfs digest
  → signed UKI
```

The UKI carries the rootfs digest it expects to find. During boot,
initrd:

1. reads the expected digest from the signed UKI
2. picks the one local deployment that matches it
3. requires active fs-verity verification
4. unlocks and switches into that deployment

If that identity is missing, malformed, or doesn't match, boot fails
immediately — there is no fallback for this case.

Because the release manifest binds the UKI digest, OCI image digest, and
rootfs digest together, artifacts from different releases can never be
mixed, even when each one is individually valid.

## Release Channels

| Channel     | What it holds                     |
|-------------|------------------------------------|
| `stable`    | Production releases                |
| `testing`   | Production-signed candidates       |
| `developer` | Local development builds           |

- A candidate moves from `testing` to `stable` unchanged — promotion
  never modifies it.
- Developer builds cannot be promoted directly into the production trust
  domain.
- Promoting a release to `stable` is a deliberate decision, not something
  that happens automatically just because CI passed.

## System Updates

### Update Pipeline

Updates are downloaded and verified in the background:

```
download
  → verify manifest and artifacts
  → stage deployment
  → stage signed UKI
  → user restart
  → trial boot
  → health verification
      ├─ fail → rollback
      └─ pass → accept
```

The OS never makes a downloaded release bootable until it has verified
the signed manifest, the artifact identities, the UKI, the rootfs
binding, and TPM authorization. Updates never force the user to end an
active desktop session.

### Trial Boot, Rollback, and Health

A newly staged deployment goes through a few states:

```
accepted → pending → trial
                        ├─ accepted
                        └─ failed → rollback
```

- Staging a deployment makes it **pending**.
- Booting it moves it to **trial**.
- ShapeBit uses systemd's Automatic Boot Assessment to count attempts
  and choose what to boot, rather than keeping a second, separate boot
  database.
- By default, a deployment gets two trial attempts.

A few more details:

- The previous accepted deployment stays available until the new one is
  durably accepted.
- A clear-cut integrity or structural failure causes an immediate
  rollback.
- A less clear-cut failure just uses up one trial attempt; once attempts
  run out, systemd-boot falls back to the previous accepted deployment.
- A failed release is blocked from being automatically re-staged until
  either a newer release supersedes it or recovery explicitly retries it.

#### Boot Health

Before a trial deployment is accepted, ShapeBit checks that:

- the release and deployment identity match what's expected
- required system storage is present
- critical platform services are running
- the network stack is functioning
- a usable graphical login environment is available

Internet access and an actual user login are **not** required.

Every one of these checks must pass and stay healthy for a short,
continuous period before the deployment is "blessed" (accepted). The
exact services checked, timeouts, retry windows, and diagnostic codes
are implementation details, not architecture.

## Release Withdrawal and Revocation

ShapeBit distinguishes between a release that's simply no longer offered
and one that has become unsafe to boot.

### Withdrawn

A release is **withdrawn** when it has a quality problem and is no
longer offered. Systems that already accepted it may keep running it
while a replacement is prepared.

### Revoked

A release is **revoked** when booting it again would be unsafe.

- Any pending or trial deployment of a revoked release is abandoned.
- If no known-safe normal deployment remains, ShapeBit enters recovery.
- Revocation records are signed and cached locally, so revocations
  already learned keep applying even while offline.
