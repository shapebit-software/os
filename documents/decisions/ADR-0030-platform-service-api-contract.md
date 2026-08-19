# ADR-0030: Platform-Service API Contract

**Status:** Accepted

**Date:** 2026-08-10

**Last updated:** 2026-08-15

## Context

ShapeBit desktop components are unprivileged, while updates, storage policy,
accounts, power management, remote access, trust changes, diagnostics, and
recovery preparation require narrowly scoped system authority. A stable
internal contract is needed so that UI restarts and service failures do not
turn those operations into an implicit root boundary or ambiguous transaction.

## Decision

### Service boundaries and names

ShapeBit uses separate system-bus services for distinct privilege domains:

| D-Bus service name | Responsibility |
|---|---|
| `software.shapebit.update` | check, download, verify, and stage system updates |
| `software.shapebit.storage` | capacity, home limits, reserve state, and safe cleanup |
| `software.shapebit.accounts` | account creation, removal, roles, and encrypted-home policy |
| `software.shapebit.power` | lid, suspend, battery, power profiles, thermals, and charge limits |
| `software.shapebit.remote_access` | system SSH and privileged sharing coordination |
| `software.shapebit.trust` | test channels, local trust keys, and trust-domain changes |
| `software.shapebit.diagnostics` | report creation, inspection, and export |
| `software.shapebit.recovery` | recovery-boot preparation and recovery-operation requests |
| `software.shapebit.platform` | read-only aggregate readiness and API inventory |

Each name is lowercase. Underscores separate words where necessary. D-Bus
names and object paths contain no hyphens; corresponding systemd units and
executables use hyphens, for example `shapebit-update.service` and
`shapebit-update`.

The platform service is not a privileged mutation proxy. It reports only
aggregate readiness, service availability, and supported interface versions.
The other eight services remain separately restartable and receive only the
authority needed for their domain.

ShapeBit does not wrap a stable upstream API merely to rename it. Desktop
components may use NetworkManager, logind, systemd-homed, PipeWire, and other
upstream interfaces directly where no ShapeBit-specific privileged policy is
required.

### Interface versioning and audience

The well-known service name and primary object path remain stable. The major API
version is a separate lowercase interface element:

```text
service:   software.shapebit.update
interface: software.shapebit.update.v1
object:    /software/shapebit/update
unit:      shapebit-update.service
```

Compatible additions retain the same major interface. An incompatible change
creates `.v2`; it never silently changes the meaning of a `.v1` method,
property, signal, or error. A daemon may expose both versions during development
or transition.

These interfaces are internal ShapeBit APIs, not a public third-party SDK.
ShapeBit Flatpaks use standard portals and freedesktop interfaces. AppImages
receive no special platform access. External callers receive no compatibility
or authorization guarantee.

The release contract declares the interface versions required by its in-image
clients and verifies the match before staging. Because bootc switches the whole
deployment and pre-acceptance rollback boots the baseline's own clients and
services, ShapeBit does not retain an unused old interface for a fixed number of
releases. It may remove that version once no supported component in the image
uses it. An interface advertised during one boot does not disappear or change
semantics during that boot.

### Caller identity and authorization

Every method belongs to exactly one authorization class:

- **non-sensitive status** available without privilege elevation;
- **own-user operation** restricted to state owned by the authenticated caller;
- **administrator operation** decided by Polkit; or
- **internal system operation** restricted to an explicit ShapeBit service.

The service obtains peer credentials from the D-Bus connection and session
state from logind. It never treats a caller-supplied UID, user name, role, bus
name, process ID, or session identifier as proof of identity. A method declares
whether an SSH session is allowed and whether an unlocked active local session
is required.

System-to-system methods combine restricted D-Bus name ownership with systemd
service identity and SELinux policy. Executable paths supplied by callers are
not identity. Passwords and authentication secrets never become D-Bus method
arguments; the trusted Polkit agent handles them under ADR-0018. Authorization
is completed before a privileged job is admitted.

### Synchronous calls and asynchronous jobs

Bounded status reads and short non-transactional changes may return directly.
An operation that can outlive a method call, has progress, or requires durable
state returns an asynchronous job object immediately.

Every job exposes an opaque identifier, operation type, sanitized initiating
identity, creation time, state, current phase, optional progress, result, and
structured failure. Its state is one of:

```text
queued | running | succeeded | failed | cancelled | interrupted
```

D-Bus signals are change hints. A client that starts or reconnects reads the
authoritative current state rather than reconstructing it from signals. Closing
the shell or Settings does not cancel system work. A job is cancellable only
when its operation declares a safe cancellation point, and cancellation is
authorized like the original operation.

Mutation requests carry an opaque caller-generated idempotency token. Repeating
the same authorized operation with that token returns the existing job or
result instead of starting a duplicate. Reusing a token for different arguments
returns `conflict`.

Power-loss-sensitive jobs store the minimum transaction state required by their
own ADR in `@state` and reconstruct the same identifier after a service restart.
A non-durable active job that cannot resume becomes `interrupted`.

### Common error contract

A rejected synchronous request returns a D-Bus error. Failure after job
admission is recorded on the job with state `failed`. Both forms provide the
same structured fields:

- a stable machine code;
- a localization key and safe parameters;
- retry guidance;
- and an optional diagnostic-report identifier.

The initial common codes are:

```text
invalid_request
not_supported
not_authorized
not_active_session
conflict
busy
insufficient_space
unavailable
integrity_failure
cancelled
interrupted
internal
```

Services do not expose raw library messages, backtraces, secrets, or arbitrary
host paths as user-facing errors. A client that does not recognize a code shows
a safe generic failure. ADR-0031 owns diagnostic detail and redaction.

### Process and job lifecycle

All services run under systemd and do not self-daemonize. `platform` and
`power` remain resident. `update` is activated by a timer, network event, or
explicit request. `storage`, `accounts`, `remote_access`, `trust`, and
`recovery` use D-Bus activation. `diagnostics` is activated by D-Bus or a fault
event, and the boot-health contract performs a write transaction before
acceptance.

Systemd may restart a failed service under a bounded restart policy. Clients
must tolerate loss and reacquisition of a well-known bus name and must not bind
correctness to a daemon PID. Durable state remains authoritative across a
process restart.

An active job remains queryable until it reaches a terminal state. A terminal
job remains queryable for 24 hours, subject to a maximum of 100 terminal jobs
per service. When the limit is exceeded, the oldest terminal job may be removed
early. Removing a D-Bus job object does not remove a required transaction log
or diagnostic report. ADR-0031 owns retention of those records. A UI may hide
an acknowledged result earlier without deleting the system record.

## Consequences

- Privilege and crash domains remain narrow and independently testable.
- Common identity, job, error, and lifecycle rules reduce custom behavior in
  each settings panel.
- The stable bus name and explicit `.v1` interface make incompatible changes
  visible without imposing a public SDK promise.
- Asynchronous jobs survive UI restarts and prevent accidental duplicate
  transactions.
- Multiple services, activation policies, Polkit rules, SELinux labels, and
  shared contract tests require more packaging than one privileged daemon.
- Upstream services remain visible architectural dependencies rather than being
  hidden behind unnecessary wrappers.

## Boundaries

This ADR owns ShapeBit platform-service names, API audience, versioning, caller
identity, authorization classes, asynchronous jobs, common errors, activation,
and job-object retention. Domain ADRs own the actual policy of each operation.
ADR-0018 owns the desktop authorization experience and credential cache.
ADR-0031 owns diagnostic schemas, redaction, consent, and record retention.
ADR-0026 owns the boot-health decision that consumes the aggregate readiness
endpoint.

## Related decisions

- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0019](ADR-0019-display-power-and-thermal-policy.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
- [ADR-0031](ADR-0031-diagnostic-reports-and-consent.md)

## References

- [D-Bus Specification](https://dbus.freedesktop.org/doc/dbus-specification.html)
