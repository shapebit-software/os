# Boot and System Lifecycle

Installation, release identity, verified boot, deployment staging, trial acceptance, updates, migration, release operations, and artifact binding.

These pages are living architecture, not implementation evidence.

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## On this page

- [Boot trust](#boot-trust)
- [Release identity and signing](#release-identity-and-signing)
- [Updates and deployment](#updates-and-deployment)
- [Installation](#installation)

## Boot trust

### Microsoft-Signed ShapeBit Shim and Separate Trust Domains

#### Purpose and constraints

ShapeBit OS must boot with Secure Boot enabled on ordinary modern x86-64
firmware without asking users to replace the firmware Platform Key or Key
Exchange Keys. Daily development must exercise the same verification mechanism
without requiring Microsoft signing or exposing production keys.

#### Design

##### Production boot compatibility

The supported production chain begins as follows:

```text
UEFI firmware
-> Microsoft 3rd Party UEFI CA
-> Microsoft-signed ShapeBit shim
-> ShapeBit boot signing certificate
-> ShapeBit boot manager and UKI
```

- ShapeBit maintains its own shim and submits it through the required shim
  review and Microsoft signing process.
- The supported path does not replace factory PK or KEK databases.
- The supported path does not require Machine Owner Key enrollment.
- Fedora's shim may be used for disposable experiments, but it is not the
  production ShapeBit trust boundary.
- The ShapeBit shim trusts only the production ShapeBit boot certificate and
  the minimum compatibility material required by the reviewed design.
- SBAT generation, revocation, certificate migration, and Microsoft `dbx`
  changes are part of the production trust lifecycle.

[Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns the subsequent UKI, sealed-deployment, PCR, and TPM2 authorization
policy.

##### Development and production separation

Development and production are separate trust domains:

- Production uses the Microsoft-signed ShapeBit shim and restricted ShapeBit
  production signing services.
- Development uses a development shim, generated local disposable keys, OVMF,
  and a software TPM.
- Central nightly artifacts use a non-production key that is not trusted by a
  normal production installation. Production-signed candidates begin at the
  `testing` stage and are promoted unchanged to `stable` as defined by [Staged Stable Rollout](boot-system-lifecycle.md).
- A single development command prepares the development keys, firmware variable
  store, software-TPM state, signed artifacts, VM, and test report.
- Development and production use the same shim source, verification rules,
  artifact formats, and test logic. They differ in certificates, signatures,
  and firmware trust configuration.
- The production shim must never trust a development key.
- Production private keys must never enter developer workstations, Git, images,
  installed disks, or general CI.

Every boot artifact and release manifest identifies its security profile as
`development` or `production`. Promotion rejects a development certificate,
development shim, development TPM enrollment, or mismatched fingerprint.

The validation tiers are:

- `fast` for tests that may omit a boot or Secure Boot and therefore provide no
  boot-security evidence;
- `development` for the full locally trusted OVMF and software-TPM path;
- `production` for release candidates using the Microsoft-signed shim and
  restricted ShapeBit signing path;
- `hardware` for the production chain on physical devices.

##### Physical threat boundary

ShapeBit protects against:

- loss or theft of a powered-off device;
- offline access to a removed disk;
- unauthorized modification of boot artifacts or a deployment;
- temporary unattended physical access without recovery credentials;
- boot of an unaccepted or revoked release within the designed policy.

ShapeBit does not claim protection against:

- an attacker controlling an already unlocked session;
- compromised firmware or malicious hardware;
- advanced laboratory attacks on memory or the TPM;
- disclosure of a password or Recovery Kit;
- compromise of ShapeBit production signing infrastructure;
- arbitrary privileged malicious code already running in an authorized boot.

#### Why this design

Microsoft signing provides compatibility with factory Secure Boot policy on
ordinary PCs. A distribution-owned shim creates a clear ShapeBit trust boundary
after firmware. Separate local development trust preserves a realistic test
path without weakening production or turning signing into a daily-development
bottleneck.

#### Benefits

- Users do not need to replace factory Secure Boot keys.
- ShapeBit controls verification after its shim starts.
- Full Secure Boot and TPM testing can run locally without production secrets.
- The production and development trust boundaries are explicit and testable.

#### Tradeoffs

- ShapeBit depends on the external shim review and Microsoft signing process.
- Factory firmware trusts a broader ecosystem than ShapeBit alone.
- Certificate transitions and global revocations require compatibility work.
- Two trust domains require strong promotion checks and separate artifacts.

#### Ownership boundaries

This section owns the firmware-to-shim compatibility choice, the ShapeBit shim
requirement, the development/production trust split, and the physical threat
boundary. [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns TPM2 PCR authorization and sealed-deployment binding.

#### When to revisit

- Microsoft signing or the 3rd Party UEFI CA becomes unavailable to ShapeBit.
- ShapeBit ships custom hardware with a separately controlled firmware root.
- MOK becomes a supported product requirement.
- The supported threat model expands to compromised firmware or hardware.

### Boot Trust and TPM2 Unlock Policy

#### Purpose and constraints

ShapeBit OS needs an encrypted system volume that unlocks without a second
password prompt. The TPM2 must release its LUKS2 key only to an approved boot
chain, while routine system updates and rollback to the trial baseline continue
to work until durable acceptance.

Binding the TPM2 key to exact kernel measurements would break automatic unlock
after every update. Trusting Secure Boot alone would authenticate EFI programs
but would not bind the encrypted deployment to its expected boot artifacts.
The design also needs explicit recovery, key rotation, and compromise
procedures before it can be treated as production security.

#### Options considered

1. Bind the LUKS2 key directly to fixed PCR values.
2. Bind it to Secure Boot state plus a signed, update-compatible PCR policy.
3. Do not use TPM2 automatic unlock and request a system passphrase at boot.

#### Design

Use option 2 for the supported production configuration.

##### Boot chain

- Use the Microsoft-signed ShapeBit shim defined by [Microsoft-Signed ShapeBit Shim and Separate Trust Domains](boot-system-lifecycle.md), followed by
  `systemd-boot` and signed ShapeBit UKIs.
- Boot signed Unified Kernel Images (UKIs) as systemd-boot Type #2 entries.
- Do not maintain a separate unsigned kernel, initramfs, or kernel command line
  on the EFI System Partition (ESP).
- Use bootc sealed-image deployment integrity for production images: the signed
  UKI carries the expected composefs digest, and fs-verity verification is
  required at boot.
- Keep the ESP unencrypted, minimal, and free of private keys and user data.
- The recovery environment follows the same Secure Boot and UKI requirements,
  with a distinct release profile.

##### TPM2 authorization

- Enroll a TPM2 LUKS2 keyslot for normal system-volume activation.
- Bind the slot directly to PCR 7, which represents Secure Boot policy state.
- Authorize PCR 11 with signed expected measurements for approved UKIs instead
  of sealing to one fixed PCR 11 value.
- Compose the PCR policy with a TPM2 NV-backed `security_epoch` condition. This
  condition is evaluated by the TPM as part of authorization; an initrd
  software comparison is not sufficient.
- Embed the PCR public key and signature in each approved UKI.
- Restrict authorization to the initrd phase used to unlock the system volume.
- Do not bind PCR 0 or PCR 2 by default; ordinary firmware and option-ROM
  updates would make recovery unnecessarily frequent.
- Do not bind PCR 14 merely because shim is present. The supported chain does
  not use MOK; revisit PCR 14 only if MOK becomes a supported policy input.

The signed PCR 11 portion uses the systemd tooling available in the target
Fedora bootc image. Until systemd provides the required composition natively, a
ShapeBit-owned LUKS2 TPM token and initrd helper constructs the complete PCR 7,
signed PCR 11, and TPM2 NV policy. The helper must use the target image's TPM2
libraries, carry no disk-unlock secret outside the TPM-sealed token, and fail
closed when the token version or policy is unsupported. Exact
`systemd-cryptenroll`, `systemd-measure`, `ukify`, and helper arguments are
implementation details pinned to and tested with that image.

##### Update and rollback window

- A release manifest defined by [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) must identify a Secure Boot-signed UKI
  and valid signed PCR 11 policy before its deployment may be staged.
- Pre-reboot validation must prove that TPM2 unlock authorizes both the pending
  deployment and its retained rollback baseline.
- The accepted deployment and the pending or trial deployment's rollback
  baseline defined by [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) form the default authorized boot window.
- The rollback baseline must remain on the ESP and authorized until the new
  deployment is durably accepted. It leaves normal boot selection after
  acceptance and before an incompatible migration commit begins.
- A failed trial boot must be able to select the previous signed UKI without a
  recovery-key prompt.

##### Security-epoch anti-rollback

Every signed system release and boot-stack manifest carries a non-decreasing
`security_epoch`. Ordinary releases remain in the current epoch. ShapeBit
increments it only at an explicit security barrier that must make older
artifacts unusable.

Each device stores its minimum authorized epoch in a dedicated monotonic TPM2
NV counter. A release-specific signed TPM policy authorizes the LUKS2 token only
when all of these conditions hold:

- PCR 7 represents the approved Secure Boot policy;
- PCR 11 represents the signed UKI and permitted initrd phase; and
- the device's NV counter is less than or equal to the release's signed
  `security_epoch`.

The epoch comparison is part of the policy authorized by the PCR policy key.
After the device counter advances, an older release policy fails inside the TPM
even if an attacker restores its UKI, policy signature, and an old copy of the
LUKS2 header. The counter is never decremented or recreated during an ordinary
update or normal recovery boot. Re-creation is permitted only after TPM clear
or replacement through the explicit recovery-key procedure below.

This is epoch-level rather than per-release anti-rollback. Older releases in
the current epoch can remain technically authorized, although normal boot
selection and signed release blocklists still restrict their use. A release
that must invalidate every earlier release starts a new epoch.

##### Epoch transition and failure behavior

A trial candidate in a higher epoch is authorized while the device counter
still names the accepted baseline's epoch, so both the candidate and baseline
remain unlockable during the trial. ShapeBit advances the counter only after:

1. the higher-epoch system deployment is durably accepted;
2. its compatible higher-epoch boot stack has booted and become the durable
   default;
3. the signed manifests, UKI policy, independent recovery environment, and
   device recovery key have been verified; and
4. the transaction record is durable and can resume after power loss.

Advancing the counter closes normal rollback to every lower epoch. Power loss
before the increment leaves the lower epoch authorized and resumes the
fix-forward transaction. Power loss after the increment must boot the verified
higher-epoch path or enter independent recovery; it must never lower the
counter or restore an older authorization policy.

TPM clear or motherboard replacement destroys the normal device-bound unlock
path. The owner unlocks with the device recovery key, and ShapeBit reprovisions
the TPM policy at the epoch of the installed, cryptographically verified
release. Recovery may preserve or raise the known floor but must not silently
select a lower epoch.

##### Prototype transition

An installation whose TPM2 LUKS2 token does not carry the ShapeBit policy
version and NV-counter identity is a prototype enrollment. It cannot be
promoted in place to the production trust model. Disposable VMs are reset;
persistent development devices are reinstalled from trusted media, recreating
the encrypted volume, TPM enrollment, and epoch counter at the current signed
release.

Deleting a legacy keyslot from only the current LUKS2 header is not a supported
migration because a retained older header can preserve that unlock route. A
future in-place migration would require a separately reviewed volume-key
rotation or re-encryption design and evidence that every retained legacy header
is unusable.

##### Key roles

Use separate keys for separate trust domains:

| Key | Purpose | Production custody |
|---|---|---|
| Microsoft 3rd Party UEFI CA | authorize the reviewed ShapeBit shim | external Microsoft and OEM trust infrastructure |
| ShapeBit boot signing key | trusted by the ShapeBit shim; sign the boot manager and UKIs | restricted release-signing service backed by an HSM |
| PCR policy key | authorize expected PCR 11 measurements | separate restricted HSM-backed service |
| OCI/release-manifest key | authorize downloaded release metadata and content | release infrastructure, separate from boot keys |
| Emergency revocation key | revoke exact releases or boot artifacts | offline, separate custody with two-person approval |
| Device recovery key | unlock one device's system LUKS2 volume | device owner only |

Production private keys must never be stored in Git, copied into an OCI image,
written to the installed disk, or exposed to general-purpose CI jobs. Builds
may receive a signing operation or short-lived secret from controlled signing
infrastructure. Development uses visibly distinct disposable test keys.

The supported path preserves the device's factory PK and KEK configuration.
ShapeBit's reviewed shim creates the ShapeBit-controlled trust boundary without
requiring custom firmware-key enrollment.

##### Hardware scope

- The first automated path is the QEMU, OVMF, and software-TPM profile defined
  by [Platform Scope and Hardware Validation](base-system.md).
- Physical laptops retain factory Secure Boot ownership and use the
  Microsoft-signed ShapeBit shim.
- ShapeBit does not define one reference laptop; physical evidence follows the
  versioned labels and test policy in [Platform Scope and Hardware Validation](base-system.md).
- Custom firmware-key enrollment and owner-managed PK/KEK configurations are
  outside the initial supported path.

##### Recovery, rotation, and revocation

- Every device keeps the independent high-entropy recovery key required by
  [TPM-Unlocked Encrypted System Volume](security-identity.md).
- Recovery-key boot must be tested after simulated PCR mismatch, Secure Boot
  database change, TPM clear, and motherboard replacement.
- ShapeBit boot-certificate and shim rotation uses an explicit overlap period in
  which the trial rollback baseline and the new release remain bootable. TPM
  enrollment is refreshed before a PCR 7-changing factory Secure Boot database
  update.
- PCR policy-key rotation creates a new TPM2 enrollment while the old policy or
  device recovery key can still unlock the volume.
- Compromise of the Secure Boot signing key requires stopping release,
  publishing a replacement trust update, revoking the compromised certificate
  where supported, and replacing affected boot artifacts.
- Compromise of the PCR policy key requires a new policy key and device TPM2
  re-enrollment; revoking only the Secure Boot key is insufficient.
- Device-side release revocation uses the separate emergency authorization and
  offline cache defined by [Staged Stable Rollout](boot-system-lifecycle.md). If no safe normal deployment remains, boot
  selection enters independent recovery.
- Recovery media may unlock the system volume only after the owner supplies the
  device recovery key. It must not automatically unlock per-user homes.

#### Why this design

A signed PCR policy separates the stable TPM2 trust anchor from measurements
that legitimately change on every OS update. PCR 7 detects changes to Secure
Boot configuration, while PCR 11 ties activation to an approved UKI. Signed
UKIs and sealed deployment integrity cover the otherwise-unencrypted boot
assets and bind them to the expected system deployment.

Separating key roles limits the effect of one compromised service. Retaining a
device recovery key prevents a firmware update, TPM failure, or key rotation
from permanently destroying access to the encrypted system volume.

#### Benefits

- Normal startup has no system-volume password prompt.
- Approved trial updates and their rollback baseline remain automatically
  unlockable until acceptance.
- Modified boot assets or an unauthorized UKI do not receive the TPM2 key.
- Production, development, boot, PCR-policy, and release-metadata trust are
  independently rotatable.
- Recovery remains possible after TPM2 or motherboard failure.

#### Tradeoffs

- Production requires external shim review and Microsoft signing.
- Factory Secure Boot trust includes a broader ecosystem than ShapeBit alone.
- Firmware trust updates can change PCR 7 and require coordinated TPM2
  re-enrollment.
- A retained, still-signed old release may remain technically bootable after
  the guaranteed rollback window closes.
- HSM-backed signing and revocation procedures add release-infrastructure work.
- Microsoft certificate transitions and `dbx` changes require compatibility
  and recovery testing.

#### Required validation

Before claiming production support, demonstrate in QEMU with OVMF and swtpm,
then on at least one `Officially-tested` laptop:

1. boot of a signed UKI with Secure Boot enabled;
2. refusal to boot a modified or untrusted UKI;
3. TPM2 unlock of the current deployment without a system passphrase;
4. refusal to auto-unlock after unauthorized PCR 7 or PCR 11 changes;
5. update from image A to trial B and automatic pre-acceptance rollback to A;
6. recovery-key unlock after TPM clear and after a Secure Boot trust change;
7. Secure Boot `db` and PCR policy-key rotation without data loss;
8. confirmation that production private keys are absent from images, ESPs,
   logs, build output, and general CI workers;
9. sealed deployment verification with fs-verity required;
10. power-loss testing during staging, epoch advancement, and trust-policy
    rotation;
11. refusal to unlock a restored lower-epoch UKI and LUKS2 header after the NV
    counter advances; and
12. recovery-key reprovisioning after TPM clear without lowering the verified
    epoch.

#### When to revisit

- ShapeBit begins shipping custom hardware or supporting custom firmware keys.
- The target systemd or bootc release changes its supported TPM2 policy or
  sealed-image mechanism.
- The target systemd gains native composition of signed PCR and TPM2 NV-counter
  policies.
- Hibernation is introduced.
- Secure Boot or PCR policy key compromise occurs.

#### Ownership boundaries

This section owns boot-chain integrity, signing-key separation, and the PCR policy
that authorizes the TPM2 LUKS2 keyslot. It does not own:

- system-volume encryption requirements, which belong to [TPM-Unlocked Encrypted System Volume](security-identity.md);
- release identity, which belongs to [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md);
- deployment state transitions and attempt counting, which belong to [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md);
- the independent recovery environment, which belongs to [Independent Recovery Environment](diagnostics-recovery.md).

## Release identity and signing

### Signed Manifest as the Immutable Release Identity

#### Purpose and constraints

An OCI tag is mutable and may point to another image. An OCI digest identifies
the system payload but does not by itself identify the matching signed UKI,
boot policy, compatibility constraints, or recovery requirements.

#### Design

Every ShapeBit OS release is identified by a signed release manifest. Schema
version 1 records:

- user-facing version and architecture;
- immutable bootc OCI image digest;
- signed UKI identity;
- required installer, updater, and recovery compatibility;
- security epoch;
- static platform requirements;
- a detached DSSE signature envelope.

Schema version 1 is closed and strict. Unknown technical fields are rejected;
the payload has no general `annotations`, extensions, or vendor-data map. A
future concrete need receives a named field in a new schema version rather than
an untyped escape hatch.

Static platform requirements declare whether the release requires UEFI, Secure
Boot, and TPM2. Model-specific hardware blocks and support evidence are mutable
operational facts and therefore live in separately authenticated release-status
metadata rather than the immutable manifest.

`architecture` is a closed enum. Schema version 1 accepts only `x86_64`, matching
the Fedora and Linux architecture name. D22 owns verification that its OCI
descriptor uses the corresponding `amd64` architecture and that `system_uki`
has the correct UEFI machine type. Supporting `aarch64` requires an explicit
schema revision and artifact-binding rules.

##### Artifact descriptors

`artifacts` is an object indexed by artifact role, not an array. Schema version
1 requires exactly these two downloadable roles:

- `system_image`;
- `system_uki`.

Every role has exactly one descriptor containing `digest`, `size`, and
`media_type`. This prevents duplicate roles and gives no semantic meaning to
object-member order. Unknown roles and unknown descriptor fields are rejected.

`system_image.media_type` is exactly
`application/vnd.oci.image.manifest.v1+json` and `system_uki.media_type` is
exactly `application/vnd.microsoft.portable-executable`. The object key
supplies the artifact role.

`size` is a non-negative decimal integer encoded as a string. Artifact digest
strings use the form `sha256:<64 lowercase hexadecimal digits>`. Each object has
one authoritative digest; alternate hashes are not included.

`rootfs` is a separate required top-level object because its digest is an
integrity value rather than a downloadable artifact descriptor. It contains
exactly `format` with the value `composefs` and `digest` in the form
`sha512:<128 lowercase hexadecimal digits>`. It has no artificial download size
or media type.

The manifest contains one required `requires` object with exactly three fields:
`installer`, `updater`, and `recovery`. Each value is a Cargo-style SemVer
requirement over a full `major.minor.patch` component version. Bare `*` is not
allowed, and a prerelease matches only when the requirement names a prerelease
explicitly. An installer or updater must satisfy its own requirement before it
performs destructive installation work or stages the release. Recovery may be
brought into compliance by the prerequisite rotation below.

An installed device must satisfy `requires.recovery` before the system release
may be staged. When necessary, the updater first installs and verifies a
compatible recovery release through its independent rotation. Failure to do so
leaves the accepted system unchanged and blocks staging of the system release.

Within `schema_version: 1`, an updater that can parse the manifest but does not
satisfy `requires.updater` must not stage the system release itself. It first
rotates to a recovery release that satisfies `requires.recovery`, then schedules
a declared restart into recovery. Recovery verifies and stages the target
system release, after which the target begins the ordinary trial lifecycle. No
temporary privileged updater is downloaded into the running system.

If the current updater cannot parse the manifest schema or cannot complete the
recovery rotation, the update is blocked without changing the accepted system.
Cross-schema bootstrapping is deferred until a second manifest schema is
actually designed.

There is no `boot_stack` component-version requirement. Shim and the boot
manager form an independently signed, device-wide, forward-only boot stack and
are deliberately excluded from a system release manifest. Their manifest,
compatibility rules, and update transaction belong to D22. PCR policy is
embedded in the per-deployment UKI and is not a separate manifest artifact.

The manifest does not contain a source-release constraint, migration head, or
migration list. The target image contains its complete ordered migration chain
and binds that code through the image digest, as defined by [Forward-Only Migrations and Trial-Bounded Rollback](boot-system-lifecycle.md).

The OCI digest remains the immutable identity of the system payload. Channel
tags and channel manifests are discovery and promotion pointers; they are not
release identities and never replace digest or signature verification.

Mutable rollout state is not inserted into, or confused with, the immutable
release manifest. Devices consume separately authenticated release-status and
revocation metadata that identifies exact immutable digests. [Staged Stable Rollout](boot-system-lifecycle.md) defines
the semantics and authorization of `withdrawn` and `revoked`.

Build timestamps, channel names, rollout waves, expiry, and provenance are also
outside the immutable manifest. Their authenticated metadata may refer to the
manifest digest without changing release identity.

##### Canonical payload and signature envelope

The payload is UTF-8 JSON serialized exactly with RFC 8785 JSON Canonicalization
Scheme (JCS). Duplicate object keys and floating-point values are invalid. A
verifier strictly parses the payload, canonicalizes it again, and requires the
resulting bytes to equal the signed payload bytes.

The payload is carried in a DSSE envelope with the exact payload type
`application/vnd.shapebit.release-manifest.v1+json`. The envelope contains at
least one signature. Every signature entry contains a non-empty `keyid` and a
signature value; duplicate `keyid` values are rejected. Multiple distinct
signatures are allowed for rotation and trust transitions. D23 owns trusted-key
selection and the number of valid signatures required for acceptance.

`manifest_digest` is the SHA-256 digest of the canonical payload bytes. It is a
computed external identity and is not stored inside its own payload. The DSSE
envelope and signatures are outside that digest, so adding a signature does not
change release identity.

##### Complete schema-v1 payload

The top-level object contains exactly `schema_version`, `version`,
`architecture`, `security_epoch`, `platform`, `requires`, `artifacts`, and
`rootfs`.

- `schema_version` is the integer `1` and agrees with the DSSE payload type.
- `version` is SemVer-compatible CalVer in `year.month.revision` form, for
  example `2026.8.0`, with no leading zero in a numeric component.
- `architecture` is `x86_64`.
- `security_epoch` is a non-negative decimal integer encoded as a string, with
  no leading zero except the value `0`. It changes only at an explicit global
  security barrier; [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns enforcement and transition rules.
- `platform` contains exactly the required Boolean members `uefi`,
  `secure_boot`, and `tpm2`.
- `requires`, `artifacts`, and `rootfs` follow the closed structures above.

Human-readable example; the DSSE payload contains its JCS serialization:

```json
{
  "schema_version": 1,
  "version": "2026.8.0",
  "architecture": "x86_64",
  "security_epoch": "1",
  "platform": {
    "uefi": true,
    "secure_boot": true,
    "tpm2": true
  },
  "requires": {
    "installer": ">=2026.8.0, <2027.0.0",
    "updater": ">=2026.8.0, <2027.0.0",
    "recovery": ">=2026.8.0, <2027.0.0"
  },
  "artifacts": {
    "system_image": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456789",
      "media_type": "application/vnd.oci.image.manifest.v1+json"
    },
    "system_uki": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "application/vnd.microsoft.portable-executable"
    }
  },
  "rootfs": {
    "format": "composefs",
    "digest": "sha512:<128 lowercase hexadecimal digits>"
  }
}
```

The payload contains no download location. Separately authenticated
distribution metadata maps each descriptor to mirrors or registry locations
without changing release identity.

#### Tradeoffs

- exact deployment reproduction;
- safe promotion of the same artifact;
- ability to block a specific digest;
- unambiguous one-descriptor-per-role artifact selection and a distinct rootfs
  integrity identity;
- binding of boot artifacts and policy to the matching system payload;
- signature rotation without changing manifest identity;
- the UI still displays a friendly release number.

### Release Artifact and Rootfs Binding

#### Purpose and constraints

[Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) identifies exact release artifacts, but independent valid signatures
do not prove that an OCI image, UKI, composefs root, boot manager, and PCR policy
belong to the same build. ShapeBit must prevent a valid artifact from one release
from being combined with a different valid artifact.

Upstream bootc integration among its composefs backend, systemd-boot, and a
vendor-signed UKI is still evolving. ShapeBit therefore cannot treat complete
boot-artifact binding as an implicit property of bootc; it needs an explicit
contract and validation gate.

#### Current design

##### OCI identity

`artifacts.system_image.digest` identifies the per-architecture OCI image
manifest for OCI architecture `amd64`, corresponding to ShapeBit architecture
`x86_64`. It does not identify a mutable tag, a multi-architecture image index,
or only an OCI image configuration object. The selected OCI manifest in turn
identifies its exact config and layer descriptors.

##### Rootfs as the boot-time join key

`rootfs.digest` is the boot-time join key between the system image and UKI:

- the release pipeline deterministically derives and verifies the composefs
  root from the exact `system_image` content;
- the final signed UKI contains the expected rootfs integrity digest;
- initrd selects only a deployment with that digest and requires fs-verity
  verification before switching to the real root; and
- any missing or unequal digest is a hard boot failure.

The final authoritative UKI is a separate release artifact and is excluded from
the content covered by the rootfs digest. The pipeline first produces the
rootfs and its digest, then builds and signs the UKI. This avoids a cycle in
which UKI bytes affect the digest embedded inside that same UKI.

The UKI does not embed `manifest_digest`. [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) already includes the UKI
digest in that manifest, so embedding the manifest digest in the UKI would also
create a self-referential build cycle. The signed release manifest instead
binds the OCI manifest, rootfs digest, and final UKI digest as peers.

The manifest represents this value as the separate `rootfs` object with
`format: composefs` and its SHA-512 digest. It is not placed in `artifacts`
because it has no separately downloaded object, size, or media type.

##### Artifact media types

The system release manifest and the independently signed boot-stack manifest
use existing format media types rather than ShapeBit-specific role media types:

- `system_image`: `application/vnd.oci.image.manifest.v1+json`;
- `shim`: `application/vnd.microsoft.portable-executable`;
- `boot_manager`: `application/vnd.microsoft.portable-executable`;
- `system_uki`: `application/vnd.microsoft.portable-executable`.

The manifest object key identifies an artifact's role. The media type identifies
its byte format and does not duplicate that role. Consumers must therefore
validate both the expected role and the expected format; accepting a valid PE
file under the wrong role is forbidden.

##### Independent device boot stack

Shim and the boot manager form one device-wide boot stack shared by all system
deployments. They are excluded from the system release manifest and described
by a separate signed boot-stack manifest that pins their exact digests, sizes,
and media types.

The boot stack has an independent lifecycle and moves only forward. Rolling
back a trial system deployment changes its UKI and rootfs selection but never
restores older shim or boot-manager bytes. This preserves boot security fixes
and avoids coupling a deployment rollback to shared EFI state.

A boot-stack update must remain capable of booting the accepted deployment and
the retained rollback deployment. ShapeBit must establish this compatibility
before changing shared EFI state. The following ordering and A/B transaction
define the required behavior; production support remains contingent on their
validation.

##### Boot-stack manifest

The boot-stack manifest is a closed UTF-8 JSON schema. Its top-level object
contains exactly `schema_version`, `boot_stack_version`, `architecture`,
`security_epoch`, and `artifacts`:

- `schema_version` is the integer `1`;
- `boot_stack_version` uses the same SemVer-compatible CalVer
  `year.month.revision` form as a system release;
- `architecture` is exactly `x86_64` in schema version 1;
- `security_epoch` uses the same non-negative decimal-string representation and
  global security-barrier meaning as the system release manifest; and
- `artifacts` contains exactly one `shim` and one `boot_manager` descriptor.

Each artifact descriptor contains exactly `digest`, `size`, and `media_type`,
using the same SHA-256 digest and decimal-string size syntax as [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md). Both
media types are exactly `application/vnd.microsoft.portable-executable`.

The payload is serialized with RFC 8785 JCS and carried in DSSE with payload
type `application/vnd.shapebit.boot-stack-manifest.v1+json`. Signature entries,
key identifiers, signature thresholds, and the SHA-256 digest of the canonical
payload follow the release-manifest rules and D23's trust policy. The computed
boot-stack manifest digest is not stored inside its payload.

Human-readable example; the signed payload contains its JCS serialization:

```json
{
  "schema_version": 1,
  "boot_stack_version": "2026.8.0",
  "architecture": "x86_64",
  "security_epoch": "1",
  "artifacts": {
    "shim": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "application/vnd.microsoft.portable-executable"
    },
    "boot_manager": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "application/vnd.microsoft.portable-executable"
    }
  }
}
```

The payload has no timestamps, channel, download locations, component
requirements, compatibility ranges, annotations, or extension map. Mutable
distribution and rollout data remains separately authenticated and keyed by
the boot-stack manifest digest.

##### Boot compatibility contract

Within one `security_epoch`, every newer boot stack must boot every
non-revoked ShapeBit system release from that epoch. Increasing
`boot_stack_version` alone must never break this compatibility. Only an
explicit global `security_epoch` transition may intentionally reject older
system releases.

Compatibility is a release qualification obligation rather than a version
range interpreted on each device. Before publication, ShapeBit must validate
the candidate shim and boot manager against the applicable non-revoked release
set in automated QEMU tests and the hardware gates defined by [Platform Scope and Hardware Validation](base-system.md). A
device validates the signed manifest, architecture, epoch, artifact identities,
and formats; it does not solve a compatibility matrix or consume a compatibility
allowlist.

A published boot stack that violates this contract is a release failure and
must not be worked around by silently dropping an installed rollback
deployment.

##### Boot-stack update ordering

A boot-stack update that remains in the current `security_epoch` may run as an
independent update before or after a system update, but only after the
compatibility qualification above succeeds. It does not alter the system trial
or acceptance state.

For an update to a higher `security_epoch`, the target system deployment first
completes its normal trial on the existing boot stack. The old epoch remains
authorized throughout that trial, preserving the rollback baseline. Only after
the target system is durably accepted does ShapeBit install the new boot stack,
advance the durable epoch barrier, and make older-epoch deployments
unbootable.

There is therefore a bounded post-acceptance transition in which the new system
is accepted but the old boot stack and epoch barrier are still active. The
transaction must record and resume this state. Failure after system acceptance
uses recovery and fix-forward completion; it never restores an older,
security-invalidated boot stack or reopens the system rollback guarantee.

This ordering deliberately accepts a short trial window in which the new system
still runs over the old boot stack. Avoiding that window would require a second
A/B lifecycle for the boot stack and would close the system rollback path before
the candidate had proved healthy.

##### A/B boot-stack installation

The ESP holds two logical boot-stack slots. Each slot contains a matched shim
and boot-manager pair and has its own UEFI boot entry. Exactly one slot is the
durably active default; an update writes only the inactive slot.

The updater verifies the candidate manifest and artifacts before writing,
writes the complete inactive slot, flushes it, reads it back, and verifies its
size, digest, PE structure, architecture, and signatures. It then sets the
inactive slot's UEFI entry through `BootNext` for one boot without changing the
durable default.

The candidate slot is promoted only after it starts the expected accepted OS
deployment, that deployment confirms the running boot-stack identity matches
the candidate manifest, and the normal mandatory health contract succeeds.
Promotion durably makes the candidate UEFI entry the default and records its
manifest digest as active. An old slot is not offered as an automatic rollback
after promotion and may be overwritten by the next update.

If power is lost before `BootNext` is set, the existing default remains active.
If the candidate does not reach promotion after `BootNext` is consumed, the
next boot returns to the unchanged default slot. If power is lost during or
after promotion, the durable transaction record must select either completion
of the candidate promotion or recovery-assisted fix-forward; it must not copy
partially written files over the known-good slot.

For a higher-epoch transition, the durable epoch barrier advances only after
the candidate boot stack has booted successfully and become the durable
default. The old slot is then removed from normal firmware selection. The TPM2
NV policy defined by [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) ensures that an old copied or manually selected stack cannot regain
TPM-backed authorization after the barrier advances.

##### ESP paths and firmware fallback

ShapeBit uses these canonical ESP paths on x86-64:

```text
EFI/ShapeBit/slot-a/shimx64.efi
EFI/ShapeBit/slot-a/shapebit-bootx64.efi
EFI/ShapeBit/slot-b/shimx64.efi
EFI/ShapeBit/slot-b/shapebit-bootx64.efi
EFI/BOOT/BOOTX64.EFI
EFI/BOOT/shapebit-bootx64.efi
```

The two `EFI/ShapeBit` directories are the transaction slots and have distinct
UEFI boot entries. ShapeBit builds its shim with
`shapebit-bootx64.efi` as the default second-stage filename, so every shim loads
the boot manager from its own directory. ShapeBit does not disguise
systemd-boot as `grubx64.efi` and does not install `MokManager.efi`,
`fallback.efi`, or `BOOT.CSV`; MOK is outside the supported trust model.

`EFI/BOOT/BOOTX64.EFI` is a byte-identical copy of the Microsoft-signed
ShapeBit shim from the last promoted stack, and its adjacent
`shapebit-bootx64.efi` is the matching signed boot manager. This generic UEFI
fallback pair permits boot after firmware variables are lost without adding a
third independently versioned stack.

The updater refreshes the generic fallback pair only after a slot promotion.
It writes and verifies the boot manager before replacing `BOOTX64.EFI`; an
interrupted fallback refresh never changes the promoted slot or its firmware
entry and is resumed from the durable transaction record. For an epoch
transition, the fallback pair must match and verify against the promoted
boot-stack manifest before the durable epoch barrier advances.

##### Recovery reconstruction

Recovery may inspect the ESP, both boot-stack slots, signatures, manifests,
transaction state, and UEFI entries without authentication. Any repair that
writes the ESP or firmware variables requires an administrator credential or
the device recovery key under [Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md).

Recovery reconstructs only artifacts identified by a valid signed boot-stack
manifest; it does not offer arbitrary EFI-file selection. Using verified local
cache or freshly downloaded artifacts, it may rebuild a damaged slot, recreate
the two UEFI slot entries, restore the generic fallback pair, or finish an
interrupted promotion. Every reconstructed object is read back and verified
before its entry is enabled.

Internal recovery can perform this work only while a trusted internal recovery
UKI and a usable boot path remain. If the ESP is unreadable or no internal boot
path survives, the user starts the same signed ShapeBit recovery environment
from external USB media. After authorization, external recovery may recreate
the ESP and its boot metadata while preserving the encrypted system volume and
per-user homes. Reformatting or repartitioning beyond the ESP is not implicit in
boot repair.

##### Verification at each trust boundary

ShapeBit revalidates artifacts at every trust boundary rather than treating a
previous success flag as proof that stored bytes remain valid.

The release build performs these operations in dependency order:

1. validate the architecture-specific OCI manifest, configuration, layers,
   media types, sizes, and digests;
2. deterministically produce the composefs root and verify its fs-verity
   identity;
3. build the UKI with the exact rootfs parameter and embedded PCR policy;
4. validate its PE structure and architecture, sign it for Secure Boot, and
   verify the final signed bytes; and
5. construct and sign the release manifest last, only after every referenced
   digest and size is final.

Boot-stack publication similarly validates and signs shim and the boot manager
before constructing and signing their manifest.

During installation or staging, the trusted client first authenticates the
release manifest and checks revocation, architecture, epoch, platform, and tool
requirements. It then retrieves descriptors by immutable digest, verifies
their sizes, media types, bytes, and nested OCI graph, produces the local
composefs deployment, and proves its rootfs identity. It validates the UKI's
digest, PE machine type, Secure Boot signature, required sections, embedded
rootfs parameter, and PCR policy. Critical objects are flushed, read back, and
verified again. The updater may create a bootable `pending` entry only after
all checks and required TPM authorization preflight succeed.

At every boot, firmware, shim, and the boot manager enforce the Secure Boot
chain to the selected UKI. The signed UKI supplies the measured command line
and PCR policy. Initrd requires exactly one matching local deployment and
active fs-verity verification before TPM-backed unlock and switching root.
Boot does not rehash the complete rootfs eagerly; fs-verity verifies data as it
is read. Userspace then verifies expected release identity and runs the normal
health contract before trial acceptance or boot-stack promotion.

Recovery trusts neither a validation flag nor unchecked bytes left by the
installed system. Starting from its own signed image, it repeats manifest,
policy, artifact, and read-back validation before enabling any reconstructed
boot path.

##### Signed UKI location

The UKI embeds the expected digest exactly once in its signed `.cmdline`
section as:

```text
rd.shapebit.rootfs=sha512:<128 lowercase hexadecimal digits>
```

The value is not secret. With Secure Boot enabled, `systemd-stub` ignores an
external attempt to replace an embedded command line. The `.cmdline` contents
are covered by the UKI Secure Boot signature and PCR 11 measurement.

Initrd rejects a missing, duplicate, malformed, unsupported-algorithm, or
unequal parameter as a hard failure. It must resolve exactly one local
deployment with that digest, require active fs-verity verification, and only
then switch to the real root. Command-line additions must not select or replace
the deployment identity.

##### PCR policy inside UKI

PCR policy is not a separate release artifact. Every `system_uki` embeds the
standard UKI `.pcrsig` section containing signed expected PCR 11 values and the
`.pcrpkey` section containing the corresponding public key. `systemd-measure`
produces the policy signatures. The UKI specification deliberately excludes
`.pcrsig` from PCR 11 measurement, avoiding a signature self-reference.

The release manifest binds the complete signed UKI digest, and the UKI carries
the PCR policy needed to authorize it. Replacing the PCR policy or public key
therefore creates a new UKI artifact and requires a new Secure Boot signature
and release manifest. ShapeBit does not support a separately replaceable PCR
policy sidecar in schema version 1.

#### Ownership boundaries

This section owns D22's artifact graph, equality checks, boot-time rootfs selection,
and failure behavior. [Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) owns the manifest schema. [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns Secure
Boot and TPM2 authorization policy. D23 owns signing-key operations and trust
thresholds.

#### Required validation

Before claiming production support, demonstrate the complete artifact-binding
design rather than inferring it from component documentation.

The automated x86-64 QEMU, OVMF, Secure Boot, and software-TPM suite must cover
installation, staging, trial, acceptance, rollback, same-epoch boot-stack
updates, higher-epoch transitions, both transaction slots, the generic UEFI
fallback path, internal recovery repair, and external recovery of a lost ESP.

Fault injection must interrupt power after every persistent checkpoint in
system staging and the A/B boot-stack transaction, including slot writing,
read-back verification, `BootNext`, candidate boot, promotion, generic fallback
refresh, and epoch-barrier advancement. Every restart must reach exactly one
safe outcome: the unchanged known-good state, resumable forward completion, or
signed recovery. It must never select a partial or mismatched artifact set.

Negative tests must independently corrupt, truncate, substitute, or mismatch
the OCI manifest or layer, composefs root, UKI and its rootfs parameter or PCR
policy, shim, boot manager, signed manifests, and durable transaction record.
Every mutation must fail closed at the earliest applicable trust boundary.

At least one laptop carrying `Officially-tested` evidence for the exact
ShapeBit release, hardware configuration, and firmware version must complete
the corresponding physical UEFI, Secure Boot, TPM2, update, interruption,
fallback, and recovery flow. This is an evidence gate, not a reference-laptop
designation. Test records must identify the test cases and exact manifest
digests under [Simple Test Evidence](base-system.md). [Platform Scope and Hardware Validation](base-system.md) continues to own recurring release-level
hardware gates.

### Production Signing Operations

#### Purpose and constraints

ShapeBit production releases require several independently usable signing
roles. Embedding unrelated operational keys directly as permanent trust anchors
would make rotation and compromise response depend on replacing every consumer.
Using one online key for every artifact would instead give one compromise the
authority to forge the complete product.

This section defines D23's production key hierarchy, custody, authorization,
signing, rotation, audit, and compromise-response contract. Development and
nightly signing remain separate trust domains under [Microsoft-Signed ShapeBit Shim and Separate Trust Domains](boot-system-lifecycle.md).

#### Current design

##### Offline root with role delegation

Production trust begins at one offline ShapeBit root. Its public trust material
is provisioned to the production system and recovery environment through their
reviewed trust anchors. The root private key never signs ordinary releases or
artifacts. It signs only versioned, expiring policy that authorizes narrowly
scoped operational keys and changes or revokes those authorizations.

Each operational key is restricted to an explicit signing role. A signature
valid for one role is invalid for every other role even when the underlying
signature algorithm is the same. Compromise or planned rotation of one
operational key therefore does not automatically require replacing unrelated
roles or the offline root.

Having one current project administrator does not collapse the roles into one
key. The same person may be authorized to operate several workflows initially,
but the private key material, policy scopes, audit identities, and rotation
paths remain distinct.

Production, development, and central nightly roots do not cross-sign one
another. No development or nightly key may chain to the production root, and a
production verifier rejects their signatures regardless of artifact contents.

##### Core operational roles

The production hierarchy delegates exactly these six core roles:

- `system-manifest` signs only immutable ShapeBit OS release manifests;
- `boot-stack-manifest` signs only device boot-stack manifests;
- `recovery-manifest` signs only independently versioned recovery manifests;
- `boot-artifact` signs only ShapeBit systemd-boot binaries and system or
  recovery UKIs for verification after shim;
- `pcr-policy` signs only expected-measurement policies carried in UKI
  `.pcrsig` sections; and
- `release-status` signs mutable distribution locations, channel pointers,
  rollout state, withdrawal, and revocation metadata.

The `boot-artifact` key does not sign shim. Microsoft signs the reviewed
ShapeBit shim that embeds or otherwise receives the applicable ShapeBit boot
trust material under [Microsoft-Signed ShapeBit Shim and Separate Trust Domains](boot-system-lifecycle.md). No core role may sign root policy, authorize
another key, or produce an artifact assigned to another role.

Using one `boot-artifact` role for systemd-boot and UKIs preserves the single
ShapeBit boot certificate already selected by [Microsoft-Signed ShapeBit Shim and Separate Trust Domains](boot-system-lifecycle.md). The manifest roles
remain separate so control of a boot-signing service alone cannot create an
update accepted by the updater. `release-status` remains separate because it
must be usable by rollout infrastructure without gaining authority to create a
new immutable release.

The role name is part of verification policy, not merely an operator label. A
cryptographically valid signature is rejected when its delegated role does not
authorize the payload type or artifact class being verified.

##### Application signing roles

The production hierarchy delegates two additional application roles:

- `application-repository` signs the ShapeBit Flatpak repository, its commits,
  and repository metadata. It may publish ShapeBit applications and
  ShapeBit-authored third-party integration artifacts, so it is treated as a
  code-distribution authority; and
- `application-recommendations` signs only the manually curated recommendation
  manifest from [Application Recommendations](application-platform.md). It cannot publish, replace, or revoke application
  packages.

ShapeBit does not delegate signing roles for Flathub, upstream Google or Fedora
packages, or AppImage publishers. Flathub retains its own repository trust.
ShapeBit integrations verify identified upstream signatures and pinned digests
without turning those external keys into ShapeBit delegates. AppImage remains
outside any ShapeBit publisher-key registry.

##### Initial hardware-token custody

Initial production signing is manual and hardware-token-backed. The offline
root and every operational private key are non-exportable token objects; they
are not stored as ordinary encrypted files, placed on developer workstations,
or exposed to CI. Root tokens are used only in an offline delegation, rotation,
or revocation ceremony. Operational tokens are used for ordinary production
signing.

CI and release tooling stop at a complete unsigned signing bundle. The bundle
contains canonical payloads or artifact digests, requested roles, source and
build identities, and references to required test evidence. A human reviews a
deterministic summary before authorizing each token operation. Only signatures
and public evidence return to the release pipeline; production private keys do
not.

Development continues to use disposable local keys, and central nightly builds
use their separate non-production trust domain. Manual production signing is
acceptable while ShapeBit has one administrator and a low release volume.

Operational roles may later move to non-exportable HSM or managed-KMS objects
when release frequency or team size justifies the infrastructure. The offline
root authorizes replacement role keys, so this migration does not change
artifact formats or require the production root private key to become online.
Such migration requires an audited key-rotation ceremony and may not copy an
existing token private key into the service.

##### Root threshold and loss tolerance

The logical production root contains three independent public keys and requires
valid signatures from any two distinct root keys. Each private key is generated
as a non-exportable object on a separate hardware token. ShapeBit does not clone
one root private key across devices and keeps no exportable root-key escrow.

The three tokens are stored separately. A root ceremony requires two tokens and
records both distinct key identifiers. One unavailable token therefore does not
block delegation or emergency response, while one stolen or compromised token
cannot change production trust by itself. Because one administrator currently
operates the project, this threshold protects against individual device loss or
compromise rather than providing independent human approval.

If one token is lost, suspected, or fails, the remaining two authorize its
revocation and a newly generated third root key in one versioned root-policy
transition. The removed key cannot return in a later policy without another
two-of-three root authorization. Loss of two current root tokens is
intentionally unrecoverable from a private-key backup and requires the separately
designed product trust-reset path rather than weakening the threshold.

##### Operational-token grouping and thresholds

Initial production uses three operational hardware tokens:

- the **manifest token** holds distinct `system-manifest`,
  `boot-stack-manifest`, and `recovery-manifest` keys;
- the **boot token** holds distinct `boot-artifact` and `pcr-policy` keys; and
- the **distribution token** holds distinct `release-status`,
  `application-repository`, and `application-recommendations` keys.

Every role key is a separate non-exportable token object with its own key
identifier and delegation. Physical co-location does not make signatures
interchangeable. Schema-v1 verification requires one valid signature by the
currently delegated key for the requested operational role; only root policy
uses a two-of-three threshold.

There is no cloned standby token or exportable operational-key backup. Loss or
failure pauses the affected workflows while the two-of-three root delegates
fresh keys on a replacement token. Suspected compromise additionally revokes
the lost keys under the compromise procedure below.

A production system, boot-stack, or recovery release normally requires both the
manifest and boot tokens: the first signs its immutable manifest and the second
signs its executable boot artifacts and PCR policy. Possession of either token
alone cannot produce the complete artifact set accepted by the updater. The
distribution token may alter rollout or application delivery within its
delegated roles but cannot create a system, boot-stack, or recovery manifest or
boot artifact.

##### Immutable signing bundles and human authorization

Production signing is never unattended. CI creates a closed signing bundle for
one operational token. It contains the product version and architecture, source
revision, bundle digest, canonical inputs or artifact digests, requested roles,
expected outputs, build identity, and references to the required test evidence.
The signing tool independently validates the closed structure and presents a
deterministic human-readable summary before requesting token authorization.

One explicit confirmation authorizes all ordered operations assigned to that
token and bundle. Nothing may be added and no input, role, or digest may change
after confirmation; any change creates a new bundle and requires new approval.
The token and signing tool reject requests outside the keys and roles named by
the bundle.

Operations follow their dependency graph. The boot-token bundle first signs
PCR policy material, constructs the final UKI containing that policy, and then
signs the resulting PE artifact. It produces an immutable receipt containing
the final signed-artifact digests. Only then may tooling construct a separate
manifest-token bundle whose manifest refers to those final digests. Thus one
approval is sufficient per token session without pretending that the final UKI
digest exists before boot signing.

Every successful or failed operation emits an append-only audit record keyed by
the signing-bundle digest. Only signatures, signed artifacts, receipts, and
public audit evidence return to the release pipeline. An emergency security
release may use the bounded testing exception in [Release Cadence and Candidate Aging](boot-system-lifecycle.md), but it receives no
exception from human signing authorization or role separation.

##### Minimal ShapeBit root policy

ShapeBit uses a small, closed root-policy format rather than adopting only a
misleading subset of TUF or duplicating TUF's complete repository workflow.
The policy is the versioned public directory of trusted keys, their exact roles,
and signature thresholds. It contains no private material.

The top-level JCS payload contains exactly `schema_version`, `version`,
`expires`, `keys`, and `roles`:

- `schema_version` is the integer `1`;
- `version` is a positive integer that increases by exactly one;
- `expires` is an RFC 3339 UTC timestamp;
- `keys` maps computed key identifiers to public-key type, signature scheme,
  and public value; and
- `roles` maps `root` and each of the eight operational roles to its authorized
  key identifiers and positive signature threshold.

The payload uses RFC 8785 JCS and a DSSE envelope with exact payload type
`application/vnd.shapebit.root-policy.v1+json`. Allowed algorithms and public
key encodings remain part of the signing-algorithm decision.

Production clients and recovery ship with root-policy version 1 as their trust
anchor. A client at version `N` accepts only version `N+1`, after verifying that
the new payload satisfies both the root threshold in trusted version `N` and
the root threshold declared by version `N+1`. It persists each accepted version
before requesting the next. Skipped, repeated with different bytes, decreasing,
malformed, incorrectly signed, or finally expired policy is rejected.

Every historical policy version remains available by version number so an old
client can verify the complete chain. This sequential dual-threshold rotation
follows TUF's root-continuity rule, but ShapeBit root policy is not described as
TUF and does not add TUF `targets`, `snapshot`, or `timestamp` roles. Existing
ShapeBit manifests and release-status metadata retain their current ownership.

##### Root-policy expiry and offline operation

Every root policy expires exactly 24 months after its issuance. Production
tooling refuses to sign or publish a new production release when the latest
policy has fewer than 90 days of validity remaining; root renewal must happen
first. Devices opportunistically retrieve sequential policy updates whenever
online.

Expiration stops the device from accepting new ShapeBit releases, delegations,
application-repository state, recommendation manifests, and mutable release
metadata until it reaches a currently valid root policy. It does not prevent
booting the accepted deployment, running already accepted applications,
starting recovery, or repairing from already accepted local artifacts. A
device must never become unbootable merely because it remained offline beyond
the policy lifetime.

An outdated device validates every missing root-policy version in sequence.
Expired intermediate policies may establish continuity, but the final policy
used to authorize new content must be currently valid. Missing versions,
failure to reach an unexpired final policy, or an invalid transition pauses new
trust and reports the condition without replacing the last trusted policy.

An old installer may perform an offline installation only from its own closed,
embedded, signed artifact set. If its bundled root policy has expired, the
installed system is marked as requiring a security-metadata refresh and may not
accept newly downloaded ShapeBit artifacts until it reaches a current policy.
The installer must describe this as outdated offline media, not as a current or
fully updated installation.

##### Non-decreasing trusted time

Each installed device persists a `trusted_time_floor`, representing the latest
reliable time it has previously accepted. The value may increase but must never
decrease. Expiry checks use the later of the current system time and this
persistent floor, so moving the local clock backward cannot restore an expired
root policy.

Ordinary boot, local application use, and recovery do not wait for time
synchronization. Before accepting newly downloaded ShapeBit trust or content,
the update path must establish reliable time through the platform time service
and advance the floor when appropriate. If network access exists but reliable
time cannot be established, new-content acceptance pauses while the current
system continues to operate.

A clock incorrectly moved far into the future can cause denial of updates but
cannot authorize new content. After administrator or device-recovery-key
authentication, recovery may repair this condition only by obtaining reliable
current time, recording the correction and previous floor in the audit report,
and then re-evaluating policy from the last trusted root version. It does not
silently lower time during normal boot.

##### Algorithms follow the native artifact format

ShapeBit does not force one signature algorithm across every production role.
Each role uses the algorithm family natively supported by the format and its
existing verification path:

- the `root`, `system-manifest`, `boot-stack-manifest`, `recovery-manifest`,
  `release-status`, and `application-recommendations` roles use ECDSA P-256
  with SHA-256 for their JCS and DSSE payloads;
- the `boot-artifact` role uses RSA-3072 with SHA-256 in X.509 Authenticode
  signatures over PE artifacts;
- the `pcr-policy` role uses RSA-3072 with SHA-256 through the native
  `systemd-measure` PCR-policy format; and
- the `application-repository` role uses the OpenPGP signing mechanism native
  to Flatpak and OSTree.

The private keys remain non-exportable token objects under the custody rules
above. Hardware-token selection must demonstrate support for every algorithm
assigned to the roles held on that token. Format-native interoperability takes
priority over reducing the hierarchy to a single algorithm family.

##### Canonical public-key identity

Every ShapeBit-managed signing key has one content-derived identifier. Its
public key is encoded as an RFC 5280 SubjectPublicKeyInfo structure in canonical
DER. JSON payloads carry those DER bytes as standard padded Base64. The key
identifier is the lowercase hexadecimal SHA-256 digest of the exact DER bytes,
prefixed with `sha256:`.

Roles and human-readable labels do not contribute to the identifier. The same
public key therefore has the same identifier wherever it is referenced, while
distinct keys cannot be made to appear related by assigning them similar
names. Verifiers reject non-canonical DER, malformed Base64, identifiers with a
different spelling, or an identifier that does not match the decoded key.

Native containers remain in use where required: Authenticode carries an X.509
certificate and the application repository carries OpenPGP key material. Their
ShapeBit policy identity still refers to the canonical SubjectPublicKeyInfo and
computed identifier for the underlying public key; their native certificate
fingerprint or OpenPGP fingerprint may be recorded as additional format-local
metadata but does not replace the ShapeBit `keyid`.

##### Canonical ECDSA signatures in DSSE

An ECDSA P-256 signature in a ShapeBit DSSE envelope is exactly 64 bytes: the
32-byte unsigned big-endian `r` value followed by the 32-byte unsigned
big-endian `s` value. The DSSE `sig` member carries those bytes as standard
padded Base64. Variable-length ASN.1 DER signatures are not accepted in this
path.

Signers normalize `s` to the lower half of the P-256 group order and verifiers
require that low-S form. Verifiers also reject a decoded length other than 64
bytes, zero or out-of-range components, non-canonical Base64, an unknown
`keyid`, a mismatch between `keyid` and public key, or a key not delegated to
the payload's required role. This gives one accepted byte representation of a
valid mathematical signature and removes ECDSA signature malleability from
artifact identity and audit comparisons.

##### Minimal OpenPGP repository profile

The `application-repository` role uses one RSA-3072 OpenPGP primary key that
directly signs Flatpak and OSTree repository commits and metadata. Schema v1
does not add a separate certification key or signing subkey. The key carries
the fixed descriptive identity `ShapeBit Application Repository` and no email
address or person name.

The OpenPGP key itself has no expiration time. Its authority and effective
validity come exclusively from the current ShapeBit root policy, so repository
verification does not have two independent expiry systems. Rotation and
revocation replace or remove its canonical ShapeBit `keyid` in root policy;
the native OpenPGP fingerprint remains format-local metadata. Historical
signatures stay attributable to the historical root-policy chain but do not
authorize current repository state after revocation.

This deliberately avoids a second OpenPGP-specific trust hierarchy. RSA-3072
is chosen for mature OpenPGP and hardware-token interoperability; its larger
signatures are acceptable for repository metadata and do not change the
algorithm choices of other roles.

##### Minimal immutable signing receipts

Every authorized production signing bundle produces one immutable
`signing-receipt.json`. The receipt records the signing-bundle digest, requested
roles and `keyid` values, source revision, build identity, digests of every
input and resulting signed artifact, signing-tool version, operation time,
outcome, operator identity, and references to the required test evidence.
Successful and partially successful receipts also contain or reference the
actual public signatures returned by the token.

The receipt is stored with the release record and copied to a separately
administered append-only archive before publication. A replacement or retry
creates a new signing bundle and receipt; it never edits or deletes the earlier
record. Failed operations are retained as audit events even when they produced
no signature. Receipts contain no PIN, recovery secret, private-key handle,
token-management credential, or other secret material.

Schema v1 does not require a public transparency log, dedicated audit-signing
role, or online audit service. Authenticity of successful outputs is checked
from the signed artifacts and delegated public keys; the receipt supplies
traceability between those outputs, their reviewed bundle, build, operator,
and evidence. The archive is operational evidence rather than an additional
device trust anchor.

##### Reproducible-build publication gate

Every production release, including an emergency security release, must be
built twice from the same source revision and pinned declared inputs in two
independent clean CI jobs. The jobs run in parallel and produce the complete
unsigned artifact set plus a machine-readable digest inventory. Production
signing bundles may be created only when the two inventories and every
corresponding unsigned artifact digest match exactly.

Signing occurs only after that comparison, so randomized or time-bearing
signature material is outside the reproducibility comparison. The resulting
receipt identifies both build jobs, their environment definitions, input
inventory, matching output inventory, and comparison report. A mismatch or a
missing second build blocks signing and retains a difference report for
diagnosis; a human may not waive the gate by marking the builds equivalent.

This doubles production build compute but normally adds only the duration of
the slower parallel job, not two sequential build durations and not a second
human ceremony. Development and local iteration may use one build; the gate
applies when creating production signing bundles.

##### Compromise response and revocation

A credible suspicion of key compromise is handled as a compromise; ShapeBit
does not continue signing while waiting for conclusive proof. Publishing for
the affected role stops immediately, the token and its credentials are
quarantined, and the incident receives an immutable audit record. The release
inventory is divided into outputs whose provenance is independently confirmed
and outputs that cannot be confirmed.

Two unaffected root keys then authorize the next sequential root policy. It
removes every affected `keyid` and, when a replacement is ready, delegates a
fresh non-exportable key. `release-status` withdraws every release whose
provenance cannot be confirmed. A replacement release is rebuilt through the
ordinary two-build gate and signed through the normal role-specific workflow;
emergency response does not create a universal signing key or bypass custody,
human confirmation, reproducibility, or evidence requirements.

Role-specific recovery adds the following actions:

- compromise of `boot-artifact` requires a replacement Microsoft-signed shim
  that trusts the replacement ShapeBit boot certificate, a higher applicable
  SBAT generation and security-epoch transition, replacement boot artifacts,
  and firmware or `dbx` revocation coordination where available;
- compromise of `pcr-policy` requires a fresh policy key and device TPM2
  re-enrollment while the prior valid policy or device recovery key still
  permits recovery;
- compromise of one root key requires the other two root keys to remove it and
  add a newly generated third key in a dual-threshold root-policy transition;
  and
- compromise or loss of two current root keys cannot be repaired by ordinary
  rotation and enters the separately designed product trust-reset procedure.

Revocation prevents the affected key from authorizing newly accepted content.
It does not delete already installed applications, make the current deployment
unbootable, or pretend that offline devices learned the revocation. Devices
apply the revocation after obtaining the sequential root-policy update and,
for boot trust, completing the coordinated boot-stack and security-epoch
transition owned by [Release Artifact and Rootfs Binding](boot-system-lifecycle.md) and [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md).

##### Strict verification and parsing

Every ShapeBit signing schema is closed and fail-closed. JSON must be valid
UTF-8 without a byte-order mark, contain no duplicate object member, satisfy
its exact schema, and reproduce the signed JCS bytes. Unknown members,
non-canonical Base64, alternate timestamp or identifier spellings, fractional
values where integers are required, out-of-range values, and signed metadata
larger than 1 MiB are rejected.

A role fixes its permitted algorithm; signed content cannot request an
alternative or weaker algorithm. Repeating a signature from the same `keyid`
never contributes more than once to a threshold. An Authenticode chain must
terminate at exactly the currently applicable delegated `boot-artifact` public
key. The application repository accepts only the single-primary-key RSA-3072
OpenPGP profile above, without additional identities or subkeys.

Malformed or unsupported input produces one explicit verification failure. A
verifier does not retry with legacy parsing, ignore unknown content, repair an
encoding, infer the author's intent, or fall back to another trust domain.
Schema evolution requires a new explicit schema version and an independently
specified compatibility transition.

#### Ownership boundaries

[Microsoft-Signed ShapeBit Shim and Separate Trust Domains](boot-system-lifecycle.md) owns Microsoft-signed shim compatibility and separation of production
from development. [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md) owns the boot and PCR authorization policy.
[Signed Manifest as the Immutable Release Identity](boot-system-lifecycle.md) and [Release Artifact and Rootfs Binding](boot-system-lifecycle.md) own the signed payloads and artifact relationships. This
architecture section owns production signing operations and delegation.

#### Required validation

Architecture approval does not establish that the production signing system is
implemented or safe to operate. Before the first production signature:

1. exercise the exact topology on real non-exportable hardware tokens: three
   independent root tokens and separate manifest, boot, and distribution
   tokens carrying all eight delegated role keys;
2. create root-policy version 1 with two distinct root signatures, then
   rehearse one-root loss, revocation, and replacement without weakening the
   two-of-three threshold;
3. demonstrate that two independent clean builds produce identical complete
   unsigned artifact inventories and that any mismatch blocks signing;
4. sign and verify system, boot-stack, recovery, application-repository, and
   application-recommendation outputs in the required bundle order;
5. reject wrong-role and wrong-key signatures, malformed or non-canonical
   payloads, invalid threshold combinations, skipped or expired root policies,
   revoked keys, and clock rollback;
6. rehearse operational-token rotation, loss, and compromise response, plus
   boot-key and PCR-policy-key recovery consequences;
7. boot, update, reject invalid artifacts, and recover the resulting signed
   system in the QEMU, OVMF, and software-TPM profile;
8. complete one signing ceremony using only the maintained procedure; and
9. archive immutable receipts and evidence containing public identifiers, tool
   versions, inputs, outputs, outcomes, and test references.

Validation evidence must never contain PINs, token-management credentials,
private-key handles, recovery secrets, or other secret material. The separate
boot-trust and hardware gates continue to govern production boot and physical
device support.

## Updates and deployment

### Release Cadence and Candidate Aging

#### Purpose and constraints

ShapeBit needs a predictable development rhythm without turning a calendar date
into permission to lower the release gates. Candidates also need enough time in
the production-signed `testing` channel to exercise ordinary daily use. A
critical security fix may occasionally need a shorter path, but it must retain
the boot, rollback, and rollout controls of an ordinary release.

#### Design

##### Stable cadence

ShapeBit targets one stable release approximately every four weeks. This is a
planning target, not a delivery promise or promotion gate. If a candidate is not
ready, ShapeBit skips the target date rather than waiving evidence or quality
requirements.

A corrected candidate does not need to wait for the next nominal four-week
window. It may be promoted whenever it completes all gates and its required
candidate-aging period. Urgent security releases may occur outside the target
cadence.

##### Ordinary candidate aging

An ordinary stable candidate must remain available in `testing` as one unchanged
artifact set for seven complete 24-hour periods. The clock begins when the exact
production-signed digest and its bound artifacts become available in `testing`.

Rebuilding, changing, or replacing any bound artifact creates a new candidate
and restarts the seven-day clock. Metadata changes that alter release identity
also restart it. Rollout status metadata that merely withdraws or pauses a
candidate does not turn it into a different candidate, but paused time does not
count toward aging.

During the period, the mandatory QEMU report, at least one complete official
physical report, update and pre-acceptance rollback from the previous stable
release, forward-migration interruption and commit-resumption tests, and
independent recovery must all pass. Absence of reported failures is not evidence
by itself.

Seven days only makes the candidate eligible. Stable promotion remains a manual
release-owner decision and never occurs automatically. Developer and nightly
artifacts have no minimum aging period.

##### Emergency security exception

The release owner may waive the seven-day aging period only when a security
vulnerability requires faster delivery. Ordinary quality defects, feature
deadlines, and missed cadence targets do not qualify.

Before emergency publication, the exact candidate must:

- pass the complete mandatory QEMU suite;
- pass a focused test that demonstrates the vulnerability is fixed;
- retain a working trial baseline and pre-acceptance rollback path; and
- receive a recorded manual decision stating the threat, reason for urgency,
  tests completed, and tests still pending.

The emergency release starts in the smallest configured rollout wave. Physical
validation may be marked `hardware validation pending`, but the complete
official physical suite must finish within 72 hours after publication. A failed
subsequent test stops rollout immediately. The release owner then withdraws the
digest or, only when another boot is unsafe, uses the independently controlled
revocation process from [Staged Stable Rollout](boot-system-lifecycle.md).

The emergency exception changes timing only. It does not bypass artifact
identity, signing, Secure Boot, trial-boot health, rollback, compatibility, or
diagnostic requirements.

#### Tradeoffs

- A four-week target gives planning rhythm without creating deadline-driven
  unsafe releases.
- Seven unchanged days provide basic real-use exposure and make the tested
  artifact identical to the promoted artifact.
- Every candidate correction restarts aging, which can delay a release.
- A security fix can move quickly after complete virtual and focused security
  testing while physical evidence follows under a short deadline.
- One release owner initially makes and records promotion and exception
  decisions, consistent with the existing governance model.

#### Ownership boundaries

This section owns the target stable cadence, ordinary candidate-aging duration, and
emergency security timing exception. [Staged Stable Rollout](boot-system-lifecycle.md) owns channel trust, immutable
promotion, staged rollout, withdrawal, and revocation. [Platform Scope and Hardware Validation](base-system.md) owns hardware
release gates. [Simple Test Evidence](base-system.md) owns test-report content and pass calculation.

### Staged Stable Rollout

#### Purpose and constraints

Even comprehensive CI and officially tested hardware cannot detect every
regression in the PC market.

#### Design

Stable is deployed in waves, with the ability to stop a specific digest
immediately.

Rollout controls discovery of an accepted signed release manifest. It does not
change the immutable release, rebuild artifacts between waves, or control the
local trial-boot and rollback state machine.

The exact wave sizes, minimum samples, and thresholds remain release-policy
parameters rather than architecture constants.

Rollout pauses automatically after a sufficient sample crosses a configured
rollback or critical-failure threshold. A confirmed signature failure,
revocation, or equivalent release-integrity failure pauses it immediately.
Only an authorized human release decision may resume a paused rollout.

Pausing discovery does not remotely remove an accepted deployment from devices
that already run it. Remediation of those devices requires a superseding
release or the separately authorized revocation mechanism below.

##### Channels and promotion

- `stable` is the only channel exposed by the normal settings interface.
- `testing` contains production-signed release candidates and is accessible
  only through developer/tester tooling.
- `nightly` uses a central non-production signing key and is not trusted by a
  normal production installation.
- `developer` uses locally generated development keys.

Nightly artifacts are never promoted directly. A selected source revision may
produce a separate production candidate, which receives the complete production
test and signing flow before entering `testing`. Only an unchanged `testing`
artifact may be promoted to `stable`: the OCI digest, UKI, manifest, and
signatures remain identical.

Passing automatic gates makes a candidate eligible but never promotes it by
itself. An authorized release owner reviews the evidence and records a signed
manual promotion decision. One explicit authorization is sufficient initially;
the separate emergency revocation operation retains its two-person requirement.

Safe switching between stable and non-stable channels is not an initial normal
product workflow. Returning from an experimental installation may require
`Reset system` or reinstallation. [Release Cadence and Candidate Aging](boot-system-lifecycle.md) defines the target cadence, minimum
time in `testing`, and emergency security exception.

#### Promotion criteria

- boot success;
- rollback rate;
- crash rate of critical components;
- no new blocking hardware issues;
- release-engineering acceptance;
- complete CI and QEMU evidence;
- the full required suite on at least one `Officially-tested` laptop;
- successful update and pre-acceptance rollback to the previous stable release;
- successful migration-chain, interruption, pre-acceptance rollback, and
  post-acceptance commit-resumption testing;
- compatible independent recovery.

#### Privacy

Devices send a minimal operational result by default:

- exact release digest;
- `accepted` or `rolled-back` outcome;
- broad failure-stage code and attempts consumed;
- a random identifier scoped to that release only.

The signal contains no user name, serial number, file list, log content, MAC
address, or stable cross-release device identifier. The rollout service does not
retain source IP addresses. The user can disable this minimal telemetry
completely without losing updates, recovery, or security metadata.

Detailed logs, precise hardware information, and boot history remain local by
default. [Diagnostic Reports and Consent](diagnostics-recovery.md) defines separate global consent for automatic detailed-report
upload without per-report prompts or content previews.

#### Withdrawal and revocation

`withdrawn` is a quality action. A withdrawn digest is no longer offered, an
unbooted staged copy is abandoned and locally blocked when the device learns of
the withdrawal, and an already accepted deployment remains running until a
superseding update is ready. The updater rechecks signed release-status metadata
until restart; an offline device uses its last authenticated status.

`revoked` is reserved for cases where another boot is unsafe, such as signing
or release-identity compromise, a known data-destroying image, or a critical
pre-protection exploit. Ordinary service vulnerabilities receive urgent fixed
images instead of boot revocation.

A revocation:

- cancels matching pending and trial deployments and may select their still
  compatible rollback baseline;
- for an already accepted release, selects only a known compatible superseding
  deployment and enters recovery when none exists; it does not assume that an
  older deployment can use committed host state;
- does not terminate an active user session automatically;
- prevents the revoked UKI from being selected on the next boot;
- enters independent recovery when no safe normal deployment exists.

Revocations use a separate offline emergency key and require approval by at
least two authorized people. The ordinary rollout-control key cannot issue one.
Devices cache the last valid signed revocation list, enforce it offline, and
refresh it whenever update metadata is checked. The list has no expiry that can
disable an offline device. ShapeBit does not claim to enforce revocations
published after a device became permanently disconnected.

### Staged-Restart UX

#### Purpose and constraints

ShapeBit downloads, verifies, and stages system updates in the background, but
[Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) requires the user to choose when an active session ends. The desktop
therefore needs a predictable way to report that an update is ready without
turning an important maintenance signal into a forced interruption.

#### Design

##### Presentation and reminder cadence

When a verified update has been staged successfully, ShapeBit immediately
posts one system notification and adds a persistent, non-intrusive restart
indicator to the system panel. The indicator remains until the pending update
is booted or withdrawn.

If the user has not restarted, ShapeBit sends the first reminder after 24
hours and subsequent reminders every 72 hours. It shows at most one such
notification in a calendar day. Notifications have no sound, are not
full-screen or modal, and do not interrupt the current activity.

ShapeBit does not assign a more intrusive cadence to security updates. Release
withdrawal and revocation remain separate safety mechanisms; this UX does not
classify waiting updates as normal or security-critical.

The user may disable restart-reminder notifications in Settings. This does not
hide the persistent panel indicator or cancel the staged update.

##### Notification actions

The notification provides three actions:

- **Restart now** opens a final confirmation that lists active local and SSH
  sessions before requesting the restart;
- **Remind tomorrow** delays the next reminder for 24 hours, after which the
  normal cadence resumes; and
- **Dismiss** closes the current notification without changing the normal
  reminder schedule.

On the lock screen, ShapeBit shows only a generic system message that a restart
is pending. It exposes no actions or update details until the user unlocks the
session. During presentation mode, full-screen activity, or screen sharing,
notification banners are deferred until that state ends; the panel indicator
remains available where the shell can safely present it.

The confirmation warns that ShapeBit cannot guarantee preservation of unsaved
application work. ShapeBit never claims to save, serialize, or restore arbitrary
application state on behalf of applications.

##### Restart and shutdown behavior

Every ordinary restart selects the staged deployment for its trial boot. The UI
does not offer a routine "restart without updating" bypass. If another local
user or an SSH session is active, restart requires an additional explicit
confirmation that identifies those active sessions.

Shutting down does not cancel the staged deployment. The next normal power-on
selects it for trial boot. ShapeBit does not schedule unattended overnight or
time-based restarts, terminate a session automatically, or force a restart.

The trial result, remaining attempts, rollback behavior, and treatment of an
unaccepted deployment are governed by [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) and [Boot Health Contract](boot-system-lifecycle.md).

#### Tradeoffs

- Users receive a durable maintenance signal without repeated daily
  interruption.
- Disabling reminder banners cannot make a pending update completely invisible.
- A normal restart has one clear meaning when an update is staged.
- Updates may wait indefinitely for a user-controlled restart.
- Active sessions receive an explicit warning, but ShapeBit cannot prevent a
  user from confirming a disruptive restart.
- Shutdown followed by power-on applies the same trial-boot safeguards as an
  immediate restart.

#### Ownership boundaries

This section owns the desktop presentation, reminder cadence, notification actions,
and the user-facing restart and shutdown behavior for an already staged update.
[Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) owns staging, trial attempts, blessing, deployment selection, and
rollback. [Media, Privacy, and Notification Policy](desktop.md) owns general notification privacy. [Boot Health Contract](boot-system-lifecycle.md) owns boot-health
evidence and failure transitions after the updated deployment starts.

### Trial Boot and Explicit Deployment Acceptance

#### Purpose and constraints

Preparing a deployment does not prove that the device will boot correctly and start the desktop.

#### Design

A newly staged deployment is `pending`. Selecting it for boot durably changes
it to `trial` and consumes one boot attempt before control passes to that
deployment. It becomes `accepted` automatically only after the mandatory health
checks succeed, it remains continuously healthy for two minutes, and a durable
success transaction completes. User login and Internet access are not required.

The limit is two trial attempts. A deterministic hard failure, including an
invalid signature or deployment identity, sealed-deployment mismatch, unsafe
required-storage activation failure, structural filesystem corruption, or
revoked release, triggers immediate rollback without using the remaining
attempt. A boot that ends before durable acceptance for an ambiguous or
transient reason consumes its attempt and may use the one remaining attempt.
This includes power loss and intentional restart or shutdown before acceptance.

A planned multi-stage update restart is a declared, bounded transition and does
not consume an extra trial attempt. An explicit recovery boot, a normal shutdown
after acceptance, and a user authentication failure are not failed trial boots.
After two unsuccessful attempts, the boot path selects the previous accepted
deployment.

A prerequisite restart into compatible recovery because the running updater
does not satisfy the target manifest is such a declared multi-stage transition.
It does not consume a target trial attempt. Trial counting begins only when the
target system deployment is selected for boot.

```text
accepted -> staged -> pending -> trial -> accepted
                                  |
                                  +-> failed -> rollback-pending -> rolled-back
```

Mandatory health checks verify boot and deployment identity, required storage,
critical system services, and a stable graphical login surface on an active
display. A closed built-in panel is not a failure when a working external
display provides the active graphical seat. The network management stack must
start, but association, DHCP, DNS, Internet access, and the presence of any
particular hot-pluggable adapter do not gate acceptance.

ShapeBit uses systemd's Automatic Boot Assessment instead of a custom
authoritative state database:

- a new UKI entry carries a two-attempt counter in its filename;
- `systemd-boot` decrements the counter before transferring control to the UKI;
- ShapeBit health units gate `boot-complete.target`;
- after the checks and two-minute observation period,
  `systemd-bless-boot.service` removes the counter and marks the entry good;
- a deterministic hard failure may mark the current entry bad immediately;
- when attempts reach zero, `systemd-boot` selects the previous good entry.

ShapeBit stores detailed diagnostic reports in `@state`, but they are not the
authority for boot selection. An incomplete acceptance remains unaccepted by
construction because the entry is not blessed. The system does not create a
second custom attempt counter or a cross-database reconciliation protocol.

No cleanup may remove the previous accepted deployment until the new deployment
is accepted. The pre-acceptance migration and compatibility contract belongs to
[Forward-Only Migrations and Trial-Bounded Rollback](boot-system-lifecycle.md). TPM2 authorization of pending and rollback boot artifacts belongs to
[Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md).
Exact health units, timeouts, observation resets, and failure transitions belong
to [Boot Health Contract](boot-system-lifecycle.md).

After automatic rollback, the failed OCI digest is locally blocked and is not
staged again automatically. A different digest may proceed normally. Recovery
may explicitly retry the blocked deployment after informed user action.

ShapeBit checks for, downloads, verifies, and stages stable updates in the
background over any working network connection. It does not distinguish
metered from unmetered networks. Downloads are resumable. Applying the staged
deployment requires a restart chosen by the user; ShapeBit does not terminate
an active session to force that restart. The staged-restart notification,
reminder, and user-facing restart behavior belong to [Staged-Restart UX](boot-system-lifecycle.md).

#### Tradeoffs

ShapeBit needs health-check units and diagnostic reporting, but boot counting
and blessing use the standard systemd interfaces.

### Boot Health Contract

#### Purpose and constraints

[Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) requires identity, storage, critical-service, network-stack, and
graphical-login checks followed by two continuous healthy minutes before a
trial deployment is accepted. Those classes need stable unit names, exact
timeouts, and deterministic failure behavior without binding the contract to
every Fedora implementation unit.

#### Design

##### Health-unit topology

ShapeBit defines five one-shot health units:

- `shapebit-health-identity.service`;
- `shapebit-health-storage.service`;
- `shapebit-health-services.service`;
- `shapebit-health-network.service`; and
- `shapebit-health-greeter.service`.

They start in parallel and are required by `shapebit-health.target`. Stable
ShapeBit wrappers may change their internal Fedora unit mapping without changing
the trial-boot contract. Successful convergence starts the continuous
observation gate before `boot-complete.target` and
`systemd-bless-boot.service`.

Every unit distinguishes a confirmed deterministic failure from an ambiguous
failure. A deterministic failure marks the deployment bad immediately. A
timeout, unavailable device, transient service failure, or insufficiently
classified error leaves the deployment unaccepted and consumes the already
started trial attempt without permanently blocking its digest.

##### Identity: 15 seconds

`shapebit-health-identity.service` performs local read-only verification. It
confirms that:

- the booted UKI entry is the expected `trial` entry;
- the mounted deployment has the expected release identity and OCI digest;
- the signed release manifest binds the booted UKI, sealed deployment, and OCI
  artifact according to the contract that D22 will define;
- the release is not locally withdrawn or revoked;
- runtime release identifiers are internally consistent; and
- the Automatic Boot Assessment counter belongs to the booted entry.

It does not require network access or attempt repair. Signature, digest,
artifact-binding, or deployment-identity mismatch is deterministic. A local
verification timeout or unreadable metadata without a classified integrity
failure is ambiguous. The timeout is 15 seconds.

##### Storage: 60 seconds

`shapebit-health-storage.service` confirms the expected system LUKS2 and Btrfs
identity, the presence and correct mounting of `@root`, `@state`, `@homes`, and
`@recovery`, and the expected filesystem UUID and subvolume identifiers. It
also confirms that approved writable sentinel locations in `@root` and `@state`
can be synchronized and that the filesystem has not been forced read-only.

The check verifies availability of inactive home-container storage in `@homes`
without activating any user's home. It does not run scrub, destructive repair,
or the still-undecided D08 capacity thresholds. A wrong filesystem identity,
missing structural subvolume, or confirmed structural corruption is
deterministic. Device delay, an unclassified I/O error, or timeout is ambiguous.
The timeout is 60 seconds.

##### Critical services: 45 seconds

`shapebit-health-services.service` uses an explicit allowlist rather than
failing on every optional systemd unit. It requires:

- the system D-Bus broker;
- `systemd-logind`;
- `systemd-homed`;
- Polkit;
- the system journal;
- the stable aggregate health endpoint for ShapeBit platform services; and
- the ShapeBit diagnostic-report writer.

Where an API exists, the unit performs a harmless readiness transaction instead
of relying only on `systemctl is-active`: D-Bus must respond, logind must return
seat state, homed must answer without activating a home, Polkit must accept a
non-privileged check, the platform aggregate must report a compatible protocol
and `ready`, and diagnostics must durably write a minimal record in `@state`.
[Platform-Service API Contract](base-system.md) owns the internal platform-service split while preserving this
aggregate.

A missing or masked required unit or incompatible required API is deterministic.
A crash, readiness timeout, or temporary unavailability is ambiguous. Optional
Bluetooth, printing, modem, hot-plug, and device-specific services do not gate
acceptance. The timeout is 45 seconds.

##### Network stack: 30 seconds

`shapebit-health-network.service` confirms that NetworkManager and
`systemd-resolved` respond, `/etc/resolv.conf` points to the controlled resolver,
loopback and kernel netlink operation are available, and the ShapeBit firewall
policy is loaded. The firewall must retain default inbound denial and agree with
NetworkManager about active profile-scoped exceptions.

Association, Ethernet link, DHCP, an external DNS answer, Internet access, and
any particular removable network device are not required. Failure to load the
required default-deny firewall policy is deterministic. NetworkManager or
resolver readiness timeout is ambiguous. The timeout is 30 seconds.

##### Graphical greeter: 90 seconds

`shapebit-health-greeter.service` requires a ready `seat0`, the independent
greeter compositor, the trusted greeter, compatible greeter/login protocol
versions, a successful frame commit and page flip on an active output, locked
pre-authentication state, and PAM-client readiness without a test login.

A closed internal panel is acceptable when an external monitor provides the
active output. With no active output, the unit waits and then reports an
ambiguous timeout. Missing mandatory greeter components or incompatible
protocols are deterministic; driver, output, or page-flip timeout is ambiguous.
The timeout is 90 seconds.

Greeter readiness is latched in volatile state for the boot. A user who logs in
immediately after a successful greeter presentation does not invalidate the
check. User authentication itself is not a health requirement.

##### Continuous observation and total deadline

After all five units succeed, every latched condition is monitored for two
continuous minutes. Loss of a condition or restart of a mandatory service resets
the two-minute clock after readiness returns. This permits one self-recovering
service restart without accepting a crash loop.

The complete health phase has a five-minute deadline from the start of the five
parallel controls. If it cannot accumulate two continuous healthy minutes
before that deadline, the result is ambiguous. A deterministic failure at any
point ends the health phase immediately.

##### Failure transition

For a deterministic failure, ShapeBit marks the deployment bad, synchronizes a
minimal diagnostic report, and restarts into the previous accepted deployment
within at most 10 seconds. Confirmed integrity failure takes precedence even if
a local or SSH session has already started.

For an ambiguous failure, the deployment remains unaccepted but is not locally
blocked as a bad digest. If no local or SSH user session exists, ShapeBit
synchronizes diagnostics and restarts into the remaining trial attempt after 30
seconds. If any user session exists, ShapeBit does not terminate it. The UI
warns that the deployment is unaccepted, and the user's next restart performs
the remaining attempt. No later deployment is staged until this trial resolves.

After both trial attempts are consumed without durable acceptance, systemd
Automatic Boot Assessment selects the previous accepted entry as defined by
[Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md).

#### Tradeoffs

- Health checks run concurrently, so their individual limits do not add
  serially during a normal boot.
- Stable wrapper units isolate the acceptance contract from Fedora service-name
  churn.
- A single self-recovering restart may still lead to acceptance, while the
  five-minute cap bounds crash-loop behavior.
- Optional or absent hardware does not roll back an otherwise healthy release.
- Confirmed integrity and structural failures prioritize rollback over unsaved
  session work; ambiguous failures preserve an active session.
- D22 and [Platform-Service API Contract](base-system.md) must satisfy the identity-binding and platform-health
  interfaces referenced by this contract before implementation can be
  considered complete.

#### Ownership boundaries

This section owns mandatory boot-health unit names, checks, timeouts, observation,
and failure transitions. [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) owns trial attempts, blessing, deployment
selection, and previous-deployment retention. [Btrfs for Persistent System State](base-system.md) owns the structural Btrfs
layout. [Network Ownership and Privacy](security-identity.md) owns ordinary network behavior and firewall policy. [Platform-Service API Contract](base-system.md)
owns platform-service APIs, and D22 owns artifact binding.

### Forward-Only Migrations and Trial-Bounded Rollback

#### Purpose and constraints

The former N/N-1 compatibility design avoided incompatible automatic migrations so that a previously
accepted deployment could remain usable indefinitely with shared persistent
state. That contract makes every host format an N/N-1 compatibility promise,
requires compatible backports, and prevents old representations from being
removed while the previous deployment remains a supported rollback target.

ShapeBit needs a simpler initial rule: an update must be safely reversible while
its new deployment is being tested, but it does not need to promise a manual
rollback after that deployment has been accepted.

#### Options considered

1. Keep every preserved host format compatible with N and N-1 indefinitely.
2. Snapshot all persistent system state and restore it with an old deployment.
3. Use forward-only migrations with a rollback boundary at trial acceptance.
4. Keep separate long-lived state generations for every host service.

#### Design

ShapeBit uses forward-only host-state migrations and guarantees deployment
rollback only until the new deployment is durably accepted.

The target bootc image carries the complete ordered migration history needed by
that image. A device jumping across several releases runs every missing
migration in order, using a durable migration ledger. The release manifest does
not need a source-release or direct-update-from field merely to enumerate an
update path.

Each incompatible migration has two phases:

1. `prepare` runs before or during the trial and may only make additive,
   idempotent, power-loss-safe changes that the old accepted deployment can
   safely ignore. The old representation remains authoritative and usable.
2. after health checks and the observation period succeed, durable deployment
   acceptance closes the rollback guarantee; `commit` may then make the new
   representation authoritative and remove data required only by the old
   deployment.

The new deployment must be able to resume an interrupted `prepare` or `commit`
and operate safely while a commit is pending. Acceptance must be durable before
any incompatible commit begins. After acceptance and before commit, ShapeBit
retires the old baseline from normal and recovery boot selection. A failure
before acceptance selects the old accepted deployment. A failure after
acceptance is repaired by resuming the forward migration, recovery, or a newer
fixed release; it does not reactivate a guaranteed old-system rollback.

Migrations are forward-only. ShapeBit does not require general reverse
migrations. A previous OCI image may remain physically cached after acceptance,
but it is not exposed as a bootable rollback target and may be removed by normal
cleanup. Strong cryptographic prevention of reintroducing an older signed boot
artifact belongs to the TPM2 anti-rollback decision.

This contract covers ShapeBit-owned persistent host state, including managed
system configuration. It does not migrate human home contents or application
data owned by Flatpak or AppImage applications. A migration that changes human
data requires a separate accepted decision.

ShapeBit does not create a whole-`@state` snapshot for an update. [No Managed Snapshots](base-system.md)'s
no-managed-snapshot policy remains in force.

This section replaces that compatibility design. It also limits the rollback operation described by
[Separate Rollback, Backup, and Reset Operations](diagnostics-recovery.md) to the pre-acceptance guarantee and defines the persistent-state side
of the acceptance boundary owned operationally by [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md).

#### Ownership boundaries

This section owns migration ordering, the prepare/commit boundary, and the duration
of the persistent-state rollback guarantee. [Trial Boot and Explicit Deployment Acceptance](boot-system-lifecycle.md) owns trial attempt
counting, health acceptance, boot selection, and blessing. The concrete
migration package format and runner protocol remain implementation design.

#### Why this design

The model follows the useful boundary of Android-style A/B updating: the system
update can return to its known-good baseline while the candidate is unaccepted,
but shared durable data is not treated as an indefinitely reversible snapshot.
It permits direct jumps through a tested migration chain without requiring
down-migrations or long-lived duplication of all system state.

#### Benefits

- Trial failure has a clear and testable rollback guarantee.
- Accepted releases may eventually remove obsolete host-state formats.
- Direct release jumps use the migration history in the target image.
- ShapeBit needs neither general reverse migrations nor update-wide snapshots.

#### Tradeoffs

- A problem discovered after acceptance cannot be solved by promising a safe
  boot of the previous deployment.
- Prepare phases must remain compatible with the old deployment.
- Commit and its ledger must be resumable after power loss.
- Recovery and fix-forward paths become important for post-acceptance failures.

#### Risks

- Accepting a deployment before its prepare work is complete could strand the
  device between formats.
- Starting commit before the old boot entry is retired could expose an
  incompatible deployment as an apparently usable boot choice.
- A destructive action accidentally placed in `prepare` could break automatic
  rollback.
- A defective commit could require recovery even though the trial boot passed.

Release validation must therefore exercise direct jumps, interruption at every
durable migration checkpoint, pre-acceptance rollback, and post-acceptance
commit resumption.

#### When to revisit

- Users require a guaranteed manual rollback days after acceptance.
- A required migration cannot be split into a backward-compatible prepare and
  a resumable forward commit.
- Concrete state size or write amplification justifies scoped generations or
  migration-specific backups.

## Installation

### GTK 4 as the ShapeBit OS Installer Frontend

#### Purpose and constraints

The ShapeBit OS installer has an unprivileged graphical frontend written in
Rust with GTK 4 through gtk-rs. Installation operations require a privileged
execution layer independent of the interface.

#### Design

**Status: Accepted.** This decision supersedes the earlier Dioxus frontend
selection. No Dioxus implementation has been verified.

```text
GTK 4 UI (Rust through gtk-rs)
→ Installer Backend API
→ storage, bootc, systemd-boot, users, and configuration
```

The UI does not perform operations directly as root.

The shared installation plan contains declarative policy but no passwords,
recovery keys, or derived secrets. Secret enrollment uses a separate,
short-lived channel to the privileged backend and is excluded from transaction
logs. [Minimal Installer Protocol](boot-system-lifecycle.md) defines the minimal ordinary protocol and plan. [One-Shot Installer Secret Channel](boot-system-lifecycle.md) defines
the one-shot secret channel.

This section selects the frontend technology and privilege boundary. Storage,
encryption, boot, and account policy remain owned by their respective architecture sections.

#### Benefits

- one maintained graphical toolkit across ShapeBit system interfaces;
- Rust and shared data models through gtk-rs;
- shared accessibility, input, text, styling, and testing knowledge;
- UI testing without destroying disks;
- possibility of reusing components in onboarding and recovery.

#### Tradeoffs

- a separate backend to maintain;
- need to validate GTK 4 and gtk-rs in the installer image;
- the graphical installer precedes the complete custom desktop environment;
- additional accessibility and error-path testing.

### Minimal Installer Protocol

#### Purpose and constraints

The unprivileged GTK frontend and privileged installer backend need one
testable local protocol. The initial installer has one accepted storage profile
and should exchange user choices rather than encode partitioning, encryption,
or command sequences supplied by the UI. Its protocol must also support a mock
backend without carrying credentials or recovery material in ordinary messages.

#### Design

##### Transport and common messages

The ordinary installer protocol uses JSON Lines over a private local Unix
socket. Each line is one complete JSON object. The socket does not listen on a
network interface, and the backend verifies the frontend's Unix peer
credentials before accepting requests. A mock backend uses the same serialized
messages.

A successful request, response, or event has at least:

```json
{"version":1,"message":"installer.writing-system","payload":{"progress":42}}
```

An error has no `message` field and has at least:

```json
{"version":1,"code":"disk-changed","payload":{"disk_model":"Example NVMe"}}
```

`message` and `code` are stable strings. `payload` is always an object, even
when empty. UI text is localized from `message` or `code`; the backend does not
make arbitrary English error text part of the contract. Payloads contain only
data safe for the unprivileged UI. Raw command output, full logs, passwords,
recovery keys, and other secrets are excluded.

The whole ordinary protocol has one integer major `version`. Optional fields
may be added within version 1 and unknown optional fields are ignored. Removing
a field, changing its meaning, or making an optional field mandatory requires
version 2. Unsupported versions return `unsupported-version`. Individual
messages, event groups, and error codes do not carry separate versions.

##### Minimal InstallationPlan

The `InstallationPlan` payload contains only choices made by the user:

- the capability-scan identifier;
- the opaque identifier of one disk returned by that scan;
- locale, time zone, and keyboard layout identifiers advertised by the backend;
- computer name;
- first-owner user name and display name; and
- an optional installer-created Wi-Fi profile identifier with
  `save_for_owner`.

It contains no password, Wi-Fi credential, recovery key, derived secret,
partition layout, encryption algorithm, Btrfs detail, command, transaction
state, or recovery acknowledgement. The backend derives those technical
details from accepted ShapeBit policy and validates the complete effective plan
before any destructive action. [Installer Disk Identity and Confirmation](boot-system-lifecycle.md) owns exact disk identity and final
confirmation; [One-Shot Installer Secret Channel](boot-system-lifecycle.md) owns secret transfer; [Installer Transaction Lifecycle](boot-system-lifecycle.md) owns execution state.

##### Capabilities

One `Capabilities` response describes the backend snapshot used to build a
plan. It contains:

- protocol version and a fresh opaque scan identifier;
- installer and target ShapeBit release version and digest;
- disks with opaque identifier, display model, capacity, eligibility, and a
  stable blocking-reason code when ineligible;
- availability of UEFI, Secure Boot, and TPM2;
- current Internet connectivity;
- available Wi-Fi adapters and whether scanning is possible; and
- supported locale, time zone, and keyboard-layout identifiers.

The visible Wi-Fi network list is dynamic and is requested separately; it is
not frozen into `Capabilities`. A plan references the capability scan that
produced its choices. The backend rejects it as `stale-capabilities` when the
relevant environment no longer matches and requires a new scan.

##### Optional installer Wi-Fi

When no working Internet connection exists, the frontend offers a Wi-Fi step.
The user may connect or skip it; lack of Internet does not block installation.
The selected password uses the [One-Shot Installer Secret Channel](boot-system-lifecycle.md) secret channel and never enters the
ordinary protocol, plan, event stream, or logs.

An installer-created connection is temporary in the live environment. If the
plan requests preservation, the backend saves it after provisioning as a
profile owned by the first user inside that user's encrypted home, not as an
automatic pre-login system profile.

When Internet already works, the installer does not interrupt the flow with a
mandatory network screen. It preserves a Wi-Fi profile only when that profile
was created by the installer. It does not silently copy credentials inherited
from an external live, laboratory, or provisioning environment.

##### Installation events

An `installation-event` message places these fields in its payload:

- transaction identifier;
- monotonically increasing sequence number;
- current step identifier;
- event kind;
- event-specific data such as optional progress from 0 through 100.

The event kinds are:

```text
step-started
progress
warning
step-completed
installation-failed
```

Each ordinary event still uses the common `message` plus `payload` envelope.
The message is a localization key. The sequence number defines ordering; UI
arrival time does not. [Installer Transaction Lifecycle](boot-system-lifecycle.md) defines step names, reconnection, replay, and
transaction completion.

##### Installer errors

An error consists only of the common `version`, string `code`, and object
`payload`. The initial codes are:

```text
unsupported-version
invalid-plan
stale-capabilities
disk-changed
insufficient-space
network-unavailable
secret-unavailable
integrity-failure
operation-failed
cancelled
internal
```

Clients must handle an unknown code as a generic failure. A payload may provide
safe structured context, but never a second free-form `message` or sensitive
diagnostic detail. Full technical evidence belongs to the local diagnostic
report under [Diagnostic Reports and Consent](diagnostics-recovery.md).

#### Tradeoffs

- The plan remains small because it expresses product choices instead of disk
  implementation steps.
- One capability snapshot avoids many partially inconsistent probe requests,
  while Wi-Fi scan results remain appropriately dynamic.
- JSON Lines is easy to inspect and mock without introducing HTTP, JSON-RPC, or
  D-Bus into the initial installer.
- One protocol version and common envelopes keep compatibility rules simple.
- The backend remains responsible for validating every choice; possession of a
  syntactically valid plan is not authorization for disk destruction.
- Wi-Fi setup improves first use without making installation depend on Internet
  access or leaking credentials into the serializable plan.

#### Ownership boundaries

This section owns the ordinary installer transport, envelope, versioning,
InstallationPlan choices, Capabilities snapshot, optional Wi-Fi behavior,
event shape, and error shape. [GTK 4 as the ShapeBit OS Installer Frontend](boot-system-lifecycle.md) owns the frontend privilege
boundary. [One-Shot Installer Secret Channel](boot-system-lifecycle.md) owns the secret channel. [Installer Transaction Lifecycle](boot-system-lifecycle.md) owns transaction semantics.
[Installer Disk Identity and Confirmation](boot-system-lifecycle.md) owns disk identity and destructive confirmation. [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) owns
Recovery Kit presentation and lifecycle.

### One-Shot Installer Secret Channel

#### Purpose and constraints

[Minimal Installer Protocol](boot-system-lifecycle.md) keeps passwords, Wi-Fi credentials, recovery keys, and derived secrets
out of the serializable installation plan and ordinary JSON Lines protocol. The
installer still needs a small local mechanism to transfer user-entered secrets
to the privileged backend and generated Recovery Kit material in the opposite
direction without temporary files, environment variables, event history, or
diagnostic capture.

#### Design

##### One-shot channel

The privileged backend creates a unique private Unix socket for one secret
transfer. The ordinary authenticated installer connection receives an opaque
request handle, purpose, direction, size limit, and expiry; it never receives
the secret itself.

The socket is created in a backend-owned runtime directory inaccessible to
other users. The backend validates Unix peer credentials and binds the request
to the authorized frontend, current installation plan or transaction, declared
purpose, and direction. The request expires after two minutes. It accepts one
successful connection and one value, then closes and removes the socket. A
handle cannot be replayed or reused.

No secret-channel socket listens on the network. Secret values never enter the
ordinary JSON Lines connection, `InstallationPlan`, capability snapshot,
events, errors, transaction state, logs, diagnostics, analytics, command-line
arguments, environment variables, or temporary files.

##### Direction and purpose

Every request declares one direction:

- `input`: the frontend sends a user-entered secret to the backend; or
- `output`: the backend sends generated Recovery Kit material to the frontend.

Every request also declares exactly one purpose. The initial input purposes are
`owner-password` and `wifi-password`; the initial output purpose is
`recovery-kit`. The frontend cannot change the purpose, direction, destination,
plan binding, or transaction binding. A secret accepted for one purpose is
never reused for another. Equal owner and Wi-Fi passwords are still transferred
as independent values.

New purposes require an explicit protocol extension. There is no unrestricted
generic `secret` purpose.

##### Binary framing and limits

The one-shot stream contains a fixed-size unsigned length followed by exactly
that number of bytes. It contains no JSON, field name, log text, or metadata.
End of stream before the declared length, trailing bytes, invalid purpose-
specific encoding, or a size beyond the declared maximum invalidates the
request and discards the received bytes.

Initial maximum sizes are:

- 1 KiB for `owner-password`;
- 1 KiB for `wifi-password`; and
- 16 KiB for `recovery-kit`.

The limits bound memory use without imposing an unnecessarily short Unicode
password limit. Purpose-specific semantic validation occurs only after the
complete bounded value has been received.

##### Input ownership and lifetime

Before transfer, the frontend owns user-entered plaintext. After successful
transfer, the backend owns the accepted copy and the frontend immediately
clears its input fields and makes a best-effort zeroization of backing buffers.
The backend retains plaintext only in memory, excludes it from core dumps,
locks its pages where supported, avoids unnecessary copies, and zeroizes each
buffer when released.

An accepted input secret is deleted immediately after its declared use and has
an absolute maximum backend lifetime of 30 minutes. If it has not been consumed
by then, the backend reports `secret-unavailable` and the frontend requests it
again. A successful provisioning step persists only its intended result: the
owner credential in the home-authentication design or the Wi-Fi credential in
the first owner's encrypted profile.

Moving back from an input screen, cancelling the field, editing an already sent
value, disconnecting the frontend, restarting the backend, or cancelling the
installation invalidates unused input requests and values. Editing creates a
new request and deletes the old accepted value immediately. A failed use, such
as rejected Wi-Fi authentication, also deletes the value; retry requires a new
transfer. The backend does not retain a failed password for an automatic later
attempt.

Loss of a secret does not itself restart a destructive phase or reformat a
disk. [Installer Transaction Lifecycle](boot-system-lifecycle.md) determines whether the transaction can wait safely for a
replacement, must stop, or must continue through recovery.

##### Recovery Kit output

After the backend generates and enrolls the independent device and first-home
recovery keys, it transfers their presentation package through one
`output/recovery-kit` request. The package preserves the distinction between the
two keys even when [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) presents them as one logical Recovery Kit.

The frontend retains the package only for the trusted presentation flow and
zeroizes it after that flow ends. If the frontend loses the package before
presentation is acknowledged, the backend does not silently rotate or generate
new enrolled keys. It may issue another one-shot output request for the same
temporarily retained keys. Unlike unused input, these already-enrolled output
keys survive a frontend reconnect while the backend remains alive, as defined
by [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md). A backend restart before acknowledgement invokes [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md)'s safe
key replacement instead of restoring plaintext from persistent state.

##### Owner-password confirmation

The frontend asks for the owner password twice and compares the two fields
locally. It transfers one copy only after they match. The backend validates the
single received value against the accepted encoding, length, and password
policy; it does not receive a confirmation copy.

Paste, password managers, and an explicit temporary reveal action remain
available. Leaving the screen or successful transfer clears both fields and
their backing buffers on a best-effort basis. A backend rejection requires the
user to enter and confirm the password again. Wi-Fi passwords are entered once.

#### Tradeoffs

- Ordinary protocol capture and mock-plan fixtures contain no credentials or
  recovery material.
- One socket, one direction, one purpose, one value, and one expiry make replay
  and accidental cross-use easy to reason about.
- The design avoids more complex file-descriptor or `memfd` transfer in the
  initial installer.
- Unix peer credentials and filesystem permissions protect the local channel,
  but compromise of the authorized frontend or backend can still expose a
  secret while it is legitimately in use.
- The 30-minute input limit may require the user to re-enter a password after a
  long pause.
- Recovery Kit plaintext has a narrowly scoped lifetime across frontend
  reconnects; [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) closes that lifecycle and defines safe replacement after
  a backend restart.

#### Ownership boundaries

This section owns the installer secret transport, direction and purpose binding,
framing, initial size and expiry limits, input ownership and lifetime,
cancellation, and local password confirmation. [GTK 4 as the ShapeBit OS Installer Frontend](boot-system-lifecycle.md) owns the installer
privilege boundary. [Minimal Installer Protocol](boot-system-lifecycle.md) owns ordinary messages. [Installer Transaction Lifecycle](boot-system-lifecycle.md) owns transaction
waiting and interruption. [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) owns Recovery Kit presentation and final
secret lifetime.

### Installer Disk Identity and Confirmation

#### Purpose and constraints

The initial installer erases one complete selected disk. Linux device names
such as `/dev/nvme0n1` are enumeration results, not persistent identities, and
can change when storage is attached, removed, or rediscovered. A plan and its
destructive confirmation must therefore remain bound to the actual device the
user reviewed, including when the target is external or lacks a reliable serial
number.

#### Design

##### Disk identity record

The privileged backend creates an opaque disk identifier from a captured
identity record. The record contains every available authoritative hardware
property and the display properties needed for confirmation:

- udev stable storage identifiers, preferring WWN where available;
- hardware serial number;
- model;
- exact byte capacity;
- transport or bus type;
- internal, external, or removable classification; and
- current kernel device path for display and access only.

The kernel path is never identity evidence. Before accepting a plan, issuing a
confirmation, and crossing the destructive boundary, the backend resolves the
opaque identifier again and compares the complete required record.

A changed stable identifier, serial number, exact capacity, transport class, or
internal/external/removable classification returns `disk-changed` and clears
selection and confirmation. A disk with conflicting identifiers, ambiguous
multipath presentation, read-only media, or active use that cannot be safely
released is ineligible in the initial installer.

Some devices expose neither a trustworthy WWN nor serial. They remain eligible
only when the remaining composite identity is unique in the current scan and
continues to match. The UI marks the identity as incomplete and requires a
separate acknowledgement on the final screen. This is a usability concession,
not a claim of stable identity across arbitrary hardware rearrangement.

##### Eligible targets

The initial installer may target an internal disk or an eligible external USB,
Thunderbolt, or eSATA disk. External and hardware-removable targets are clearly
labelled. They must meet the same minimum capacity and ordinary validation as an
internal disk.

The storage device containing or backing the running installer environment is
never eligible. Neither are read-only devices, ambiguous multipath devices, or
targets with mounts, swap, holders, or other active use that the backend cannot
prove safe to release before confirmation.

An external or removable target adds a separate acknowledgement that disconnect
during installation can leave the disk incomplete and disconnect afterward
prevents ShapeBit from booting. No target is preselected.

##### Final destructive confirmation

Immediately before `creating-storage`, the frontend shows one final screen with:

- ShapeBit OS as the system to install;
- disk model and exact human-readable capacity;
- serial number when available;
- internal, external, or removable classification; and
- an explicit statement that the complete disk and all its data will be
  irreversibly erased.

The user must select **I understand that all data on this disk will be
deleted** before enabling **Erase disk and install ShapeBit**. The installer does
not require typing a model, serial, `ERASE`, or another confirmation phrase.

An incomplete hardware identity or external/removable target requires its
additional acknowledgement on the same screen. These acknowledgements do not
replace the ordinary destructive checkbox.

The backend, not the UI, issues a one-use confirmation token bound to the exact
disk identity record, capability scan, plan, target release digest, and active
backend instance. It expires after 10 minutes. Any mismatch, expiry,
disconnection, or backend restart invalidates it. The token authorizes only the
single transition into `creating-storage` for that transaction and cannot be
replayed.

##### Stale plan and rescan rules

The capability snapshot and disk selection become stale when:

- any storage device is attached or removed;
- any selected-disk identity or eligibility property changes;
- the selected disk becomes mounted, active, read-only, or otherwise in use;
- the target ShapeBit digest changes;
- required UEFI, Secure Boot, or TPM2 availability changes;
- the privileged backend restarts; or
- the user changes the selected target.

An unrelated monitor, input device, or network-state change does not make the
disk plan stale. Dynamic Wi-Fi results remain outside the storage snapshot as
defined by [Minimal Installer Protocol](boot-system-lifecycle.md).

When a plan becomes stale, the installer preserves unrelated safe form values,
including locale, time zone, keyboard choice, computer name, and first-owner
names. It clears the disk selection and every destructive acknowledgement and
token. The user must rescan, select the target again, and repeat final
confirmation.

The backend performs one final identity, eligibility, and active-use check
after consuming the confirmation token and immediately before the first
destructive write. A failure performs no destructive operation.

##### Interrupted installations

A valid [Installer Transaction Lifecycle](boot-system-lifecycle.md) transaction journal identifies an already modified target with
the same disk identity record. Continuing that exact transaction does not ask
the user to authorize the original erase again, but it revalidates identity and
every completed checkpoint. Choosing **Start over**, losing reliable target
identity, or lacking a valid journal requires a new scan and final destructive
confirmation.

#### Tradeoffs

- Device enumeration changes cannot silently redirect a confirmed erase to a
  different disk.
- The confirmation screen remains readable and does not rely on ritual text
  entry.
- Hot-plugging any storage device intentionally invalidates the selection,
  which is conservative but may require repeating the final step.
- External installation remains possible, with its disconnect risk made
  explicit.
- Devices without stable identifiers remain usable under a visibly weaker,
  current-scan-only identity rule.
- A backend restart cannot reuse an old destructive authorization.

#### Ownership boundaries

This section owns target-disk identity, eligibility checks related to identity and
active use, external-target warnings, final destructive confirmation, token
expiry, and stale-plan behavior. [Initial Installation and Storage Profile](base-system.md) owns whole-disk installation and the
storage profile. [Minimal Installer Protocol](boot-system-lifecycle.md) owns the capability and plan envelopes. [Installer Transaction Lifecycle](boot-system-lifecycle.md) owns
transaction phases, interruption, and continuation after destruction.

### Installer Transaction Lifecycle

#### Purpose and constraints

Once the installer starts erasing the selected disk, closing the UI, losing
power, or retrying an unsafe step must not create a second uncontrolled
operation or a false success result. The initial lifecycle needs understandable
phases, one explicit destructive boundary, durable progress without secrets,
and conservative recovery rather than a general rollback mechanism.

#### Design

##### Installation phases

One installation transaction advances through these ordered phases:

```text
validating
preparing
creating-storage
installing-system
configuring
verifying
```

- `validating` rechecks the plan, capability snapshot, selected disk, required
  inputs, and current policy without changing the target;
- `preparing` obtains available non-secret inputs and prepares the operation
  while leaving the target unchanged;
- `creating-storage` erases the selected disk and creates the GPT, system LUKS2,
  Btrfs layout, and encrypted-home storage foundations;
- `installing-system` writes the exact ShapeBit image and boot artifacts;
- `configuring` provisions the first owner, home, optional Wi-Fi profile, TPM2,
  trust, recovery, and device configuration; and
- `verifying` checks the complete installation and synchronizes it before
  success.

The backend is the authority for phase and step state. The frontend presents
events but cannot skip, reorder, or mark a phase complete. There is only one
active transaction for a selected target disk.

##### Destructive boundary and stopping

`validating` and `preparing` are non-destructive and expose ordinary **Cancel**.
[Installer Disk Identity and Confirmation](boot-system-lifecycle.md)'s final disk confirmation authorizes one transition into
`creating-storage`; beginning that phase is the destructive boundary.

After the boundary, ordinary cancellation is unavailable. Closing or crashing
the UI does not stop the privileged backend, which continues when it can do so
safely. A reconnected UI attaches to the same transaction and reads its current
state and event sequence.

The UI may expose a separate strongly warned **Stop installation** action after
the boundary. It requests a controlled stop at the next backend-declared safe
point. The disk may remain incomplete and unbootable and will require resume or
reinstallation. Stopping does not restore the disk's previous contents.

Power loss, backend termination, or loss of the live environment is an
interruption, not cancellation. Cancelling or stopping invalidates all
unneeded secret requests and plaintext according to [One-Shot Installer Secret Channel](boot-system-lifecycle.md).

##### Durable transaction journal and checkpoints

Before the destructive boundary, transaction state is temporary because the
target has not changed and the plan can be started again. After the boundary,
the target disk carries a small durable, secret-free installation journal. The
backend establishes its durable location as early as the storage layout safely
allows and synchronizes it after every completed checkpoint.

The journal records only:

- transaction and protocol identifiers;
- target release digest;
- the [Installer Disk Identity and Confirmation](boot-system-lifecycle.md) target-disk identity;
- completed phase and step identifiers;
- monotonic event sequence;
- current lifecycle state; and
- safe last-error and retry metadata.

It never contains passwords, Wi-Fi credentials, Recovery Kit values, derived
keys, raw command output, or sensitive logs.

A step is complete only after its effects are verified and its checkpoint is
durably synchronized. Files or partitions observed without a matching valid
checkpoint do not prove completion. If interruption happens before a valid
journal can be established, the disk is treated as an incomplete target that
can only be started again after [Installer Disk Identity and Confirmation](boot-system-lifecycle.md) confirmation.

##### Resume and start over

On startup, the installer scans eligible disks for a valid incomplete ShapeBit
installation journal. It offers:

- **Continue installation**, which revalidates disk identity, release inputs,
  journal integrity, and already completed checkpoints before proceeding; or
- **Start over**, which requires a new destructive confirmation and recreates
  the installation on the already modified disk.

Continue begins after the last verified checkpoint. A phase interrupted before
its checkpoint runs again according to its declared idempotent recovery rule.
In particular, incomplete `creating-storage` may be recreated from the
beginning because the previous data was already irreversibly lost. The backend
never guesses completion from residual files.

If required artifacts no longer match the journal, the disk identity changed,
or the recorded operation is incompatible with the running installer, resume
is blocked. The UI explains the stable reason and may offer start over, not an
unsafe conversion of the old transaction.

##### Waiting, failure, and retry

The backend classifies each step in advance as safely retryable or terminal
under specified preconditions. The frontend does not infer this classification.

- resumable network downloads may continue automatically;
- `secret-unavailable` pauses at a safe point and requests a new one-shot
  transfer when the transaction can wait;
- a retryable failed step exposes **Try again**, revalidates its preconditions,
  and remains part of the same transaction;
- there is no fixed retry-count limit while repeated attempts remain safe and
  require informed user action; and
- integrity failure, disk-identity change, or serious unclassified storage I/O
  failure is not retried automatically and moves the transaction to `failed`.

A failed transaction retains its diagnostic reference and journal until the
user chooses a permitted retry, resumes later, or confirms start over. Failure
does not initiate another format operation by itself.

##### Verification and completion

The `verifying` phase confirms at minimum:

- the expected GPT, LUKS2, and Btrfs identities and layout;
- the exact installed image digest;
- required signed UKIs, systemd-boot entries, and recovery assets;
- valid system and first-home keyslots;
- usable TPM2 system unlock and both enrolled recovery credentials;
- the first-owner record and activation of its encrypted home;
- the first-owner Wi-Fi profile when preservation was requested; and
- synchronized data followed by safe unmounting of target filesystems.

Internet access is not a completion requirement. Recovery-credential testing
must not disclose values or revoke the working keyslots.

After every verification succeeds, [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md)'s presentation gate requires the
current Recovery Kit to be presented and acknowledged. Only then does the
backend durably write an installation-complete marker, emit the terminal
`completed` result, and remove the resumable transaction journal. If
interruption occurs between those actions, the complete marker takes precedence
and permits safe cleanup of the stale journal.

Installer completion means that required disk state was verified. It is not
evidence that the particular physical computer completed its first real boot;
that remains part of the QEMU and hardware test contracts in [Simple Test Evidence](base-system.md).

#### Tradeoffs

- The user can cancel freely before data loss and receives a distinct warning
  for emergency stopping afterward.
- UI failure does not abandon a privileged disk operation or create a second
  transaction.
- Durable checkpoints permit conservative continuation without storing
  credentials in transaction state.
- Some interrupted storage work is restarted rather than resumed at a finer
  granularity, which is simpler and safer but may take longer.
- Backend-declared retryability avoids both blind retry loops and an arbitrary
  fixed attempt count.
- Success is stronger than command completion but does not overclaim evidence
  of an actual first boot.

#### Ownership boundaries

This section owns installer phases, the destructive boundary, cancellation and
controlled stop behavior, durable checkpoints, resume, retry, failure, and
completion verification. [Minimal Installer Protocol](boot-system-lifecycle.md) owns message and event envelopes. [One-Shot Installer Secret Channel](boot-system-lifecycle.md)
owns secret lifetime. [Installer Disk Identity and Confirmation](boot-system-lifecycle.md) owns disk identity and final destructive
confirmation. [Recovery Kit Presentation and Lifecycle](diagnostics-recovery.md) owns Recovery Kit presentation after the credentials
have been enrolled and tested.
