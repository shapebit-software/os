# ADR-0009: Staged Stable Rollout

**Status:** Proposed
**Date:** 2026-08-04

## Context

Even comprehensive CI and reference hardware cannot detect every regression in the PC market.

## Decision

Stable is deployed in waves, with the ability to stop a specific digest immediately.

Rollout controls discovery of an accepted signed release manifest. It does not
change the immutable release, rebuild artifacts between waves, or control the
local trial-boot and rollback state machine.

Proposed waves:

```text
internal → 1% → 5% → 20% → 50% → 100%
```

## Promotion criteria

- boot success;
- rollback rate;
- crash rate of critical components;
- no new blocking hardware issues;
- release-engineering acceptance.

## Privacy

Cohort assignment should be deterministic and as anonymous as possible.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md) defines release identity.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines device-side
  deployment state.
