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
descriptor uses the corresponding `amd64` architecture and that every boot
artifact has the correct UEFI machine type. Supporting `aarch64` requires an
explicit schema revision and artifact-binding rules.

### Artifact descriptors

`artifacts` is an object indexed by artifact role, not an array. Schema version
1 requires exactly these six roles:

- `system_image`;
- `shim`;
- `boot_manager`;
- `system_uki`;
- `pcr_policy`; and
- `integrity.rootfs`.

Every role has exactly one descriptor containing `digest`, `size`, and
`media_type`. This prevents duplicate roles and gives no semantic meaning to
object-member order. Unknown roles and unknown descriptor fields are rejected.

`size` is a non-negative decimal integer encoded as a string. Digest strings use
the form `<algorithm>:<lowercase hexadecimal>`. Schema version 1 requires
SHA-256 with exactly 64 hexadecimal digits for every downloadable artifact and
SHA-512 with exactly 128 hexadecimal digits for `integrity.rootfs`. Each object
has one authoritative digest; alternate hashes are not included.

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

There is no separate `boot_stack` version requirement. The manifest identifies
the exact shim, boot-manager, UKI, PCR-policy, and integrity artifacts; their
verifiable compatibility and binding belong to the planned D22 artifact-binding
decision rather than an opaque component-version range.

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
`architecture`, `security_epoch`, `platform`, `requires`, and `artifacts`.

- `schema_version` is the integer `1` and agrees with the DSSE payload type.
- `version` is SemVer-compatible CalVer in `year.month.revision` form, for
  example `2026.8.0`, with no leading zero in a numeric component.
- `architecture` is `x86_64`.
- `security_epoch` is a non-negative decimal integer encoded as a string, with
  no leading zero except the value `0`. It changes only at an explicit global
  security barrier; D24 owns enforcement and transition rules.
- `platform` contains exactly the required Boolean members `uefi`,
  `secure_boot`, and `tpm2`.
- `requires` and `artifacts` follow the closed structures above.

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
      "media_type": "<defined by D22>"
    },
    "shim": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "<defined by D22>"
    },
    "boot_manager": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "<defined by D22>"
    },
    "system_uki": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "<defined by D22>"
    },
    "pcr_policy": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "<defined by D22>"
    },
    "integrity.rootfs": {
      "digest": "sha512:<128 lowercase hexadecimal digits>",
      "size": "123456789",
      "media_type": "<defined by D22>"
    }
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
- unambiguous one-descriptor-per-role artifact selection;
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
