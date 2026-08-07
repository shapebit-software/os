# ADR-0006: Signed Manifest as the Immutable Release Identity

**Status:** Proposed
**Date:** 2026-08-04
**Last updated:** 2026-08-07

## Context

An OCI tag is mutable and may point to another image. An OCI digest identifies
the system payload but does not by itself identify the matching signed UKI,
boot policy, compatibility constraints, or recovery requirements.

## Decision

Every ShapeBit OS release is identified by a signed release manifest. At
minimum, the manifest records:

- release ID and architecture;
- immutable bootc OCI image digest;
- signed UKI identity;
- required bootloader and updater compatibility;
- security epoch;
- minimum supported source release;
- hardware blocks;
- recovery compatibility;
- manifest signature.

The OCI digest remains the immutable identity of the system payload. Channel
tags and channel manifests are discovery and promotion pointers; they are not
release identities and never replace digest or signature verification.

Mutable rollout state is not inserted into, or confused with, the immutable
release manifest. Devices consume separately authenticated release-status and
revocation metadata that identifies exact immutable digests. ADR-0009 defines
the semantics and authorization of `withdrawn` and `revoked`.

## Consequences

- exact deployment reproduction;
- safe promotion of the same artifact;
- ability to block a specific digest;
- binding of boot artifacts and policy to the matching system payload;
- the UI still displays a friendly release number.

## Related decisions

- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines the device-side
  lifecycle of a release.
- [ADR-0009](ADR-0009-staged-rollout.md) defines channel rollout.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) defines boot and TPM2 trust.
