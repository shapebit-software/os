# ADR-0015: Microsoft-Signed ShapeBit Shim and Separate Trust Domains

**Status:** Accepted
**Date:** 2026-08-06

## Context

ShapeBit OS must boot with Secure Boot enabled on ordinary modern x86-64
firmware without asking users to replace the firmware Platform Key or Key
Exchange Keys. Daily development must exercise the same verification mechanism
without requiring Microsoft signing or exposing production keys.

## Decision

### Production boot compatibility

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

ADR-0013 owns the subsequent UKI, sealed-deployment, PCR, and TPM2 authorization
policy.

### Development and production separation

Development and production are separate trust domains:

- Production uses the Microsoft-signed ShapeBit shim and restricted ShapeBit
  production signing services.
- Development uses a development shim, generated local disposable keys, OVMF,
  and a software TPM.
- Central nightly artifacts use a non-production key that is not trusted by a
  normal production installation. Production-signed candidates begin at the
  `testing` stage and are promoted unchanged to `stable` as defined by ADR-0009.
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

### Physical threat boundary

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

## Rationale

Microsoft signing provides compatibility with factory Secure Boot policy on
ordinary PCs. A distribution-owned shim creates a clear ShapeBit trust boundary
after firmware. Separate local development trust preserves a realistic test
path without weakening production or turning signing into a daily-development
bottleneck.

## Positive consequences

- Users do not need to replace factory Secure Boot keys.
- ShapeBit controls verification after its shim starts.
- Full Secure Boot and TPM testing can run locally without production secrets.
- The production and development trust boundaries are explicit and testable.

## Negative consequences

- ShapeBit depends on the external shim review and Microsoft signing process.
- Factory firmware trusts a broader ecosystem than ShapeBit alone.
- Certificate transitions and global revocations require compatibility work.
- Two trust domains require strong promotion checks and separate artifacts.

## Boundaries

This ADR owns the firmware-to-shim compatibility choice, the ShapeBit shim
requirement, the development/production trust split, and the physical threat
boundary. ADR-0013 owns TPM2 PCR authorization and sealed-deployment binding.

## Re-evaluation criteria

- Microsoft signing or the 3rd Party UEFI CA becomes unavailable to ShapeBit.
- ShapeBit ships custom hardware with a separately controlled firmware root.
- MOK becomes a supported product requirement.
- The supported threat model expands to compromised firmware or hardware.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0014](ADR-0014-platform-and-hardware-validation.md)
- [ADR-0009](ADR-0009-staged-rollout.md)
