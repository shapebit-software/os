# ADR-0009: Staged Stable Rollout

**Status:** Proposed  
**Date:** 2026-08-04

## Context

Even comprehensive CI and reference hardware cannot detect every regression in the PC market.

## Decision

Stable is deployed in waves, with the ability to stop a specific digest immediately.

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
