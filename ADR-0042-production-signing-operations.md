# ADR-0042: Production Signing Operations

**Status:** Proposed
**Date:** 2026-08-17
**Last updated:** 2026-08-18

## Context

ShapeBit production releases require several independently usable signing
roles. Embedding unrelated operational keys directly as permanent trust anchors
would make rotation and compromise response depend on replacing every consumer.
Using one online key for every artifact would instead give one compromise the
authority to forge the complete product.

This ADR defines D23's production key hierarchy, custody, authorization,
signing, rotation, audit, and compromise-response contract. Development and
nightly signing remain separate trust domains under ADR-0015.

## Decisions established so far

### Offline root with role delegation

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

### Core operational roles

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
trust material under ADR-0015. No core role may sign root policy, authorize
another key, or produce an artifact assigned to another role.

Using one `boot-artifact` role for systemd-boot and UKIs preserves the single
ShapeBit boot certificate already selected by ADR-0015. The manifest roles
remain separate so control of a boot-signing service alone cannot create an
update accepted by the updater. `release-status` remains separate because it
must be usable by rollout infrastructure without gaining authority to create a
new immutable release.

The role name is part of verification policy, not merely an operator label. A
cryptographically valid signature is rejected when its delegated role does not
authorize the payload type or artifact class being verified.

### Application signing roles

The production hierarchy delegates two additional application roles:

- `application-repository` signs the ShapeBit Flatpak repository, its commits,
  and repository metadata. It may publish ShapeBit applications and
  ShapeBit-authored third-party integration artifacts, so it is treated as a
  code-distribution authority; and
- `application-recommendations` signs only the manually curated recommendation
  manifest from ADR-0024. It cannot publish, replace, or revoke application
  packages.

ShapeBit does not delegate signing roles for Flathub, upstream Google or Fedora
packages, or AppImage publishers. Flathub retains its own repository trust.
ShapeBit integrations verify identified upstream signatures and pinned digests
without turning those external keys into ShapeBit delegates. AppImage remains
outside any ShapeBit publisher-key registry.

### Initial hardware-token custody

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

### Root threshold and loss tolerance

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

### Operational-token grouping and thresholds

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
the lost keys under the compromise procedure still to be defined.

A production system, boot-stack, or recovery release normally requires both the
manifest and boot tokens: the first signs its immutable manifest and the second
signs its executable boot artifacts and PCR policy. Possession of either token
alone cannot produce the complete artifact set accepted by the updater. The
distribution token may alter rollout or application delivery within its
delegated roles but cannot create a system, boot-stack, or recovery manifest or
boot artifact.

### Immutable signing bundles and human authorization

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
release may use the bounded testing exception in ADR-0034, but it receives no
exception from human signing authorization or role separation.

### Minimal ShapeBit root policy

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

### Root-policy expiry and offline operation

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

### Non-decreasing trusted time

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

### Algorithms follow the native artifact format

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

The precise DSSE signature encoding, OpenPGP key profile, and remaining parser
strictness remain to be fixed before this ADR can be accepted.

### Canonical public-key identity

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

### Canonical ECDSA signatures in DSSE

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

### Minimal OpenPGP repository profile

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

### Minimal immutable signing receipts

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

### Reproducible-build publication gate

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

### Compromise response and revocation

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
transition owned by ADR-0041 and D24.

### Strict verification and parsing

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

## Boundaries

ADR-0015 owns Microsoft-signed shim compatibility and separation of production
from development. ADR-0013 owns the boot and PCR authorization policy.
ADR-0006 and ADR-0041 own the signed payloads and artifact relationships. This
ADR owns production signing operations and delegation.

## Remaining decisions

- Required validation before acceptance.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0041](ADR-0041-release-artifact-and-rootfs-binding.md)
