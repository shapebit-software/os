# ADR-0007: Trial Boot and Explicit Deployment Acceptance

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-15

## Context

Preparing a deployment does not prove that the device will boot correctly and start the desktop.

## Decision

A newly staged deployment is `pending`. Selecting it for boot durably changes
it to `trial` and consumes one boot attempt before control passes to that
deployment. It becomes `accepted` automatically only after the mandatory health
checks succeed, it remains continuously healthy for two minutes, and a durable
success transaction completes. User login and Internet access are not required.

The limit is two trial attempts. A deterministic hard failure, including an
invalid signature or deployment identity, sealed-deployment mismatch, unsafe
required-storage activation failure, structural filesystem corruption, or
revoked release, triggers immediate rollback without using the remaining
attempt. A boot that ends before durable acceptance for an ambiguous or
transient reason consumes its attempt and may use the one remaining attempt.
This includes power loss and intentional restart or shutdown before acceptance.

A planned multi-stage update restart is a declared, bounded transition and does
not consume an extra trial attempt. An explicit recovery boot, a normal shutdown
after acceptance, and a user authentication failure are not failed trial boots.
After two unsuccessful attempts, the boot path selects the previous accepted
deployment.

A prerequisite restart into compatible recovery because the running updater
does not satisfy the target manifest is such a declared multi-stage transition.
It does not consume a target trial attempt. Trial counting begins only when the
target system deployment is selected for boot.

```text
accepted -> staged -> pending -> trial -> accepted
                                  |
                                  +-> failed -> rollback-pending -> rolled-back
```

Mandatory health checks verify boot and deployment identity, required storage,
critical system services, and a stable graphical login surface on an active
display. A closed built-in panel is not a failure when a working external
display provides the active graphical seat. The network management stack must
start, but association, DHCP, DNS, Internet access, and the presence of any
particular hot-pluggable adapter do not gate acceptance.

ShapeBit uses systemd's Automatic Boot Assessment instead of a custom
authoritative state database:

- a new UKI entry carries a two-attempt counter in its filename;
- `systemd-boot` decrements the counter before transferring control to the UKI;
- ShapeBit health units gate `boot-complete.target`;
- after the checks and two-minute observation period,
  `systemd-bless-boot.service` removes the counter and marks the entry good;
- a deterministic hard failure may mark the current entry bad immediately;
- when attempts reach zero, `systemd-boot` selects the previous good entry.

ShapeBit stores detailed diagnostic reports in `@state`, but they are not the
authority for boot selection. An incomplete acceptance remains unaccepted by
construction because the entry is not blessed. The system does not create a
second custom attempt counter or a cross-database reconciliation protocol.

No cleanup may remove the previous accepted deployment until the new deployment
is accepted. The pre-acceptance migration and compatibility contract belongs to
ADR-0040. TPM2 authorization of pending and rollback boot artifacts belongs to
ADR-0013.
Exact health units, timeouts, observation resets, and failure transitions belong
to ADR-0026.

After automatic rollback, the failed OCI digest is locally blocked and is not
staged again automatically. A different digest may proceed normally. Recovery
may explicitly retry the blocked deployment after informed user action.

ShapeBit checks for, downloads, verifies, and stages stable updates in the
background over any working network connection. It does not distinguish
metered from unmetered networks. Downloads are resumable. Applying the staged
deployment requires a restart chosen by the user; ShapeBit does not terminate
an active session to force that restart. The staged-restart notification,
reminder, and user-facing restart behavior belong to ADR-0027.

## Consequences

ShapeBit needs health-check units and diagnostic reporting, but boot counting
and blessing use the standard systemd interfaces.

## Related decisions

- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
  owns migrations and closes the persistent-state rollback guarantee at durable
  acceptance.
- [ADR-0006](ADR-0006-signed-release-manifest.md) owns release identity.
- [ADR-0008](ADR-0008-independent-recovery.md) owns recovery.
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md) owns boot authorization.
- [ADR-0026](ADR-0026-boot-health-contract.md) owns health checks and timeouts.
- [ADR-0027](ADR-0027-staged-restart-ux.md) owns staged-restart notifications,
  reminders, and user-facing restart behavior.

## References

- [systemd Automatic Boot Assessment](https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/)
