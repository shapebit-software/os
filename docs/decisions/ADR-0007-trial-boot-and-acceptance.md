# ADR-0007: Trial Boot and Explicit Deployment Acceptance

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-07

## Context

Preparing a deployment does not prove that the device will boot correctly and start the desktop.

## Decision

A newly staged deployment is `pending`. Selecting it for boot durably changes
it to `trial` and consumes one boot attempt before control passes to that
deployment. It becomes `accepted` automatically only after the mandatory health
checks succeed, it remains continuously healthy for two minutes, and a durable
success transaction completes. User login and Internet access are not required.

The limit is two trial attempts. A deterministic hard failure, including an
invalid signature or deployment identity, sealed-deployment mismatch, critical
migration failure, unsafe required-storage activation failure, structural
filesystem corruption, or revoked release, triggers immediate rollback without
using the remaining attempt. A boot that ends before durable acceptance for an
ambiguous or transient reason consumes its attempt and may use the one remaining
attempt. This includes power loss and intentional restart or shutdown before
acceptance.

A planned multi-stage update restart is a declared, bounded transition and does
not consume an extra trial attempt. An explicit recovery boot, a normal shutdown
after acceptance, and a user authentication failure are not failed trial boots.
After two unsuccessful attempts, the boot path selects the previous accepted
deployment.

```text
accepted -> staged -> pending -> trial -> accepted
                                  |
                                  +-> failed -> rollback-pending -> rolled-back
```

Mandatory health checks verify boot and deployment identity, required storage,
critical migrations, critical system services, and a stable graphical login
surface on an active display. A closed built-in panel is not a failure when a
working external display provides the active graphical seat. The network
management stack must start, but association, DHCP, DNS, Internet access, and
the presence of any particular hot-pluggable adapter do not gate acceptance.

The boot-attempt record, selected deployment, transaction ID, and acceptance
marker must survive power loss. Acceptance is fail-safe: any incomplete,
contradictory, or corrupt acceptance state is treated as not accepted. The
durable design uses redundant small records with generation identifiers and
checksums rather than relying only on UEFI variables. Detailed journal state
and boot-selection state must agree before the deployment becomes accepted.

No cleanup may remove the previous accepted deployment until the new deployment
is accepted. Crossing the separate rollback barrier defined by ADR-0004 also
requires explicit owner authorization.

Critical migration success is an input to acceptance, but migration semantics
belong to ADR-0004. TPM2 authorization of pending and rollback boot artifacts
belongs to ADR-0013.

## Consequences

We need a health agent, persistent markers, boot counting, and bootloader integration.

## Open questions

- Which component is the sole writer for each state transition.
- The exact record format, physical locations, reconciliation protocol, and
  authentication of boot-selection metadata.
- Exact service names and timeouts inside each mandatory health-check class.

## Related decisions

- [ADR-0004](ADR-0004-data-migrations-and-rollback.md) owns migrations.
- [ADR-0006](ADR-0006-signed-release-manifest.md) owns release identity.
- [ADR-0008](ADR-0008-independent-recovery.md) owns recovery.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) owns boot authorization.
