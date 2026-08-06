# ADR-0007: Trial Boot and Explicit Deployment Acceptance

**Status:** Proposed
**Date:** 2026-08-04

## Context

Preparing a deployment does not prove that the device will boot correctly and start the desktop.

## Decision

A newly staged deployment is `pending`. Selecting it for boot atomically changes
it to `trial` and consumes one boot attempt. It becomes `accepted` only after
required boot, base-system, device, and critical-migration checks succeed and a
persistent success marker is written.

The default limit is three failed trial boots. After the limit, the boot path
selects the previous accepted deployment. A normal shutdown after acceptance,
an explicit recovery boot, and a user authentication failure are not failed
trial boots.

```text
accepted -> staged -> pending -> trial -> accepted
                                  |
                                  +-> failed -> rollback-pending -> rolled-back
```

The boot-attempt record, selected deployment, transaction ID, and acceptance
marker must survive power loss. No cleanup may remove the previous accepted
deployment until the new deployment is accepted.

Critical migration success is an input to acceptance, but migration semantics
belong to ADR-0004. TPM2 authorization of pending and rollback boot artifacts
belongs to ADR-0013.

## Consequences

We need a health agent, persistent markers, boot counting, and bootloader integration.

## Open questions

- Which component is the sole writer for each state transition?
- Where is the power-loss-safe state record stored?
- What minimum observation period is required after reaching the base system?

## Related decisions

- [ADR-0004](ADR-0004-data-migrations-and-rollback.md) owns migrations.
- [ADR-0006](ADR-0006-signed-release-manifest.md) owns release identity.
- [ADR-0008](ADR-0008-independent-recovery.md) owns recovery.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) owns boot authorization.
