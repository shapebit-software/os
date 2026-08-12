# ADR-0034: Release Cadence and Candidate Aging

**Status:** Accepted

**Date:** 2026-08-12

## Context

ShapeBit needs a predictable development rhythm without turning a calendar date
into permission to lower the release gates. Candidates also need enough time in
the production-signed `testing` channel to exercise ordinary daily use. A
critical security fix may occasionally need a shorter path, but it must retain
the boot, rollback, and rollout controls of an ordinary release.

## Decision

### Stable cadence

ShapeBit targets one stable release approximately every four weeks. This is a
planning target, not a delivery promise or promotion gate. If a candidate is not
ready, ShapeBit skips the target date rather than waiving evidence or quality
requirements.

A corrected candidate does not need to wait for the next nominal four-week
window. It may be promoted whenever it completes all gates and its required
candidate-aging period. Urgent security releases may occur outside the target
cadence.

### Ordinary candidate aging

An ordinary stable candidate must remain available in `testing` as one unchanged
artifact set for seven complete 24-hour periods. The clock begins when the exact
production-signed digest and its bound artifacts become available in `testing`.

Rebuilding, changing, or replacing any bound artifact creates a new candidate
and restarts the seven-day clock. Metadata changes that alter release identity
also restart it. Rollout status metadata that merely withdraws or pauses a
candidate does not turn it into a different candidate, but paused time does not
count toward aging.

During the period, the mandatory QEMU report, at least one complete official
physical report, update and rollback from the previous stable release, N/N-1
persistent-state compatibility, and independent recovery must all pass. Absence
of reported failures is not evidence by itself.

Seven days only makes the candidate eligible. Stable promotion remains a manual
release-owner decision and never occurs automatically. Developer and nightly
artifacts have no minimum aging period.

### Emergency security exception

The release owner may waive the seven-day aging period only when a security
vulnerability requires faster delivery. Ordinary quality defects, feature
deadlines, and missed cadence targets do not qualify.

Before emergency publication, the exact candidate must:

- pass the complete mandatory QEMU suite;
- pass a focused test that demonstrates the vulnerability is fixed;
- retain a working previous deployment and rollback path; and
- receive a recorded manual decision stating the threat, reason for urgency,
  tests completed, and tests still pending.

The emergency release starts in the smallest configured rollout wave. Physical
validation may be marked `hardware validation pending`, but the complete
official physical suite must finish within 72 hours after publication. A failed
subsequent test stops rollout immediately. The release owner then withdraws the
digest or, only when another boot is unsafe, uses the independently controlled
revocation process from ADR-0009.

The emergency exception changes timing only. It does not bypass artifact
identity, signing, Secure Boot, trial-boot health, rollback, compatibility, or
diagnostic requirements.

## Consequences

- A four-week target gives planning rhythm without creating deadline-driven
  unsafe releases.
- Seven unchanged days provide basic real-use exposure and make the tested
  artifact identical to the promoted artifact.
- Every candidate correction restarts aging, which can delay a release.
- A security fix can move quickly after complete virtual and focused security
  testing while physical evidence follows under a short deadline.
- One release owner initially makes and records promotion and exception
  decisions, consistent with the existing governance model.

## Boundaries

This ADR owns the target stable cadence, ordinary candidate-aging duration, and
emergency security timing exception. ADR-0009 owns channel trust, immutable
promotion, staged rollout, withdrawal, and revocation. ADR-0014 owns hardware
release gates. ADR-0033 owns test-report content and pass calculation.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0009](ADR-0009-staged-rollout.md)
- [ADR-0014](ADR-0014-platform-and-hardware-validation.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
- [ADR-0033](ADR-0033-simple-test-evidence.md)
