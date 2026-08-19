# ADR-0006: Signed Manifest as the Immutable Release Identity

**Status:** Proposed
**Date:** 2026-08-04
**Last updated:** 2026-08-15

## Context

An OCI tag is mutable and may point to another image. An OCI digest identifies
the system payload but does not by itself identify the matching signed UKI,
boot policy, compatibility constraints, or recovery requirements.

## Decision

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

### Artifact descriptors

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
and binds that code through the image digest, as defined by ADR-0040.

The OCI digest remains the immutable identity of the system payload. Channel
tags and channel manifests are discovery and promotion pointers; they are not
release identities and never replace digest or signature verification.

Mutable rollout state is not inserted into, or confused with, the immutable
release manifest. Devices consume separately authenticated release-status and
revocation metadata that identifies exact immutable digests. ADR-0009 defines
the semantics and authorization of `withdrawn` and `revoked`.

Build timestamps, channel names, rollout waves, expiry, and provenance are also
outside the immutable manifest. Their authenticated metadata may refer to the
manifest digest without changing release identity.

### Canonical payload and signature envelope

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

### Complete schema-v1 payload

The top-level object contains exactly `schema_version`, `version`,
`architecture`, `security_epoch`, `platform`, `requires`, `artifacts`, and
`rootfs`.

- `schema_version` is the integer `1` and agrees with the DSSE payload type.
- `version` is SemVer-compatible CalVer in `year.month.revision` form, for
  example `2026.8.0`, with no leading zero in a numeric component.
- `architecture` is `x86_64`.
- `security_epoch` is a non-negative decimal integer encoded as a string, with
  no leading zero except the value `0`. It changes only at an explicit global
  security barrier; D24 owns enforcement and transition rules.
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

## Consequences

- exact deployment reproduction;
- safe promotion of the same artifact;
- ability to block a specific digest;
- unambiguous one-descriptor-per-role artifact selection and a distinct rootfs
  integrity identity;
- binding of boot artifacts and policy to the matching system payload;
- signature rotation without changing manifest identity;
- the UI still displays a friendly release number.

## Related decisions

- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines the device-side
  lifecycle of a release.
- [ADR-0009](ADR-0009-staged-rollout.md) defines channel rollout.
- [ADR-0008](ADR-0008-independent-recovery.md) defines recovery rotation and
  verification.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) defines boot and TPM2 trust.
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
  defines the in-image migration chain.
