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

Until ShapeBit's own shim is signed, machines boot through Fedora's shim,
which Microsoft signed, and keep their factory keys:

```
UEFI Secure Boot
  → Fedora's shim
  → dev-signed systemd-boot
  → dev-signed UKI
```

Shim trusts the development key only once a person enrolls its certificate as
a Machine Owner Key: the first boot of the installer medium stops at shim's
MOK manager, once per machine, and needs no password. Moving to ShapeBit's own
shim is the path to no such step.

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

### Developer Preview

The OS is a rolling release: an image has no release line, only its build:
`IMAGE_VERSION` in `os-release` is the build date and the
monorepo commit, such as `20261030_e0920a`. Images are published to
`ghcr.io/shapebit-software/os` with these tags:

| Tag               | Set by                                    | What it holds                                  |
|-------------------|-------------------------------------------|------------------------------------------------|
| `candidate`       | The Weekly workflow, once every test passed | The latest build that passed every test      |
| `stable`          | The Release workflow, started by a person | What installed systems update from             |
| `stable-previous` | The Release workflow                      | The release before, for undoing a release      |
| `iso`             | The Release workflow, when it publishes the installer medium | The image the current medium installs |

The Weekly workflow builds an image each week, or when started by hand, with no
build cache, so that it picks up Fedora's updates. It tests the image and its
medium fully ([Testing](Testing)), and publishes it as `candidate` only if every
test passes, with a report of the commits and packages changed since `stable`.
A person can try the candidate on a real machine with `bootc switch`, then start
the Release workflow, which moves `stable`, and `iso` with it when asked, to the
candidate unchanged, and publishes the medium that the same Weekly run tested:
`installer.raw.zst`, with the medium before it kept as
`installer-previous.raw.zst`. `IMAGE_REVISION` in `os-release` and the image's
`org.opencontainers.image.revision` label name the full commit.

#### Signing Keys

Each key signs systemd-boot, the UKI, and its PCR values. Two keys are used
until the production hierarchy above exists:

| Key           | Certificate name       | CI secret             | Readable by                 | State |
|---------------|------------------------|-----------------------|-----------------------------|-------|
| `dev.key`     | `ShapeBit Development` | none                  | Local builds; pull requests and pushes generate a throwaway one | In use for development |
| `release.key` | `ShapeBit`             | `RELEASE_KEY` | The Weekly workflow's build job, in the environment `Signing`, on `main` | Signs every candidate, so every `stable` |

Machines that enrolled the development key must enroll the release key.
Promotion copies an image unchanged, so the key is chosen when the image is
built. Builds never generate the release key.

The release key is a GitHub secret for now. Whoever can approve a release can ship code to
every machine, so the safety of the approver's account matters as much as the
key's.

#### Path to a Public Release

These steps are planned; none is done yet.

Before anyone outside ShapeBit's test machines installs:

- Create the release key, with an offline backup, and change the Release
  workflow to build, sign, and test as described above.
- Require a hardware security key or passkey for everyone in the GitHub
  organization.
- Protect `main`, and restrict the `Release` environment to `main`, with a
  required reviewer.
- Pin every action in the workflows to a commit, and give the signing key only
  to the steps that sign.
- Sign release images, with machines refusing any others.
- Let updates replace shim, so that a revoked shim does not stop machines from
  booting.

Before a public release:

- Move the release key to hardware-backed signing, so that the private key never
  reaches a CI runner.
- Replace the third-party Hyprland repository, whose packages the release key
  would otherwise vouch for, with Fedora's packages or ShapeBit's own builds.
- Get ShapeBit's own shim reviewed and signed by Microsoft, so that a PC with its
  factory keys boots without the MOK step, and migrate machines to it by an
  update, including their TPM enrollment.
- Have a shim signed with Microsoft's 2023 certificate, which newer PCs may
  trust alone.
- Test on a range of real PCs.

The production key hierarchy above, with its offline root, follows as the project
and its release process grow.

## Distribution

Where each kind of software is published, so that it needs no servers of
ShapeBit's own:

| What | Where | State |
|------|-------|-------|
| OS images | GHCR, `ghcr.io/shapebit-software/os`, with the tags in [Developer Preview](#developer-preview) | Built: the Image and Release workflows of the [monorepo](https://github.com/shapebit-software/os) |
| Installer medium | Cloudflare R2, at a fixed name for the website to link to, at most two media: `installer.raw.zst` and `installer-previous.raw.zst` | The Release workflow uploads it; the bucket and its domain are not set up yet |
| ShapeBit's own apps | A Flatpak repository of ShapeBit's own (the OS repository of [Applications](Architecture-Applications#installing-apps)), built with [AetherPak](https://github.com/aetherpak/actions): apps as OCI images on GHCR, their index on GitHub Pages | Decided; not built, as there are no such apps yet |
| ShapeBit's own RPMs | None: the image installs ShapeBit's components directly, and the image's version is theirs | Decided. If something outside the image ever needs them, a signed repository built by GitHub Actions on GitHub Pages |

Third-party software comes from Fedora's repositories (into the image) and
from Flathub and Fedora's Flatpaks (onto the computer); ShapeBit does not
mirror it.

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

### Checking for Updates

Installed systems follow `stable`. `os-update` checks it soon after boot and
then every 6 hours, but not on a metered connection unless the user asks
with **Check now** in Settings. It downloads a new image and stages it; the
next restart or shutdown installs it, and it never restarts by itself. Its
state, for the desktop, is in `/run/os-update/status.json`.

Until the release manifest and image signatures exist, an update is accepted
by its registry and tag alone; the staged UKI is still checked by Secure
Boot when it boots.

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
