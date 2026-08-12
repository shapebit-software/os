# ADR-0009: Staged Stable Rollout

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-12

## Context

Even comprehensive CI and officially tested hardware cannot detect every
regression in the PC market.

## Decision

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

### Channels and promotion

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
`Reset system` or reinstallation. ADR-0034 defines the target cadence, minimum
time in `testing`, and emergency security exception.

## Promotion criteria

- boot success;
- rollback rate;
- crash rate of critical components;
- no new blocking hardware issues;
- release-engineering acceptance;
- complete CI and QEMU evidence;
- the full required suite on at least one `Officially-tested` laptop;
- successful update and rollback from the previous stable release;
- successful N/N-1 preserved-state compatibility testing;
- compatible independent recovery.

## Privacy

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
default. ADR-0031 defines separate global consent for automatic detailed-report
upload without per-report prompts or content previews.

## Withdrawal and revocation

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

- cancels matching pending and trial deployments;
- selects a known safe previous or superseding deployment for the next boot;
- does not terminate an active user session automatically;
- prevents the revoked UKI from being selected on the next boot;
- enters independent recovery when no safe normal deployment exists.

Revocations use a separate offline emergency key and require approval by at
least two authorized people. The ordinary rollout-control key cannot issue one.
Devices cache the last valid signed revocation list, enforce it offline, and
refresh it whenever update metadata is checked. The list has no expiry that can
disable an offline device. ShapeBit does not claim to enforce revocations
published after a device became permanently disconnected.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md) defines release identity.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines device-side
  deployment state.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) defines boot-signing trust.
- [ADR-0031](ADR-0031-diagnostic-reports-and-consent.md) defines detailed
  diagnostic reports and their separate upload consent.
- [ADR-0034](ADR-0034-release-cadence-and-candidate-aging.md) defines release
  timing and candidate aging.
