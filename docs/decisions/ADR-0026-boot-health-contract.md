# ADR-0026: Boot Health Contract

**Status:** Accepted

**Date:** 2026-08-09

## Context

ADR-0007 requires identity, storage, critical-service, network-stack, and
graphical-login checks followed by two continuous healthy minutes before a
trial deployment is accepted. Those classes need stable unit names, exact
timeouts, and deterministic failure behavior without binding the contract to
every Fedora implementation unit.

## Decision

### Health-unit topology

ShapeBit defines five one-shot health units:

- `shapebit-health-identity.service`;
- `shapebit-health-storage.service`;
- `shapebit-health-services.service`;
- `shapebit-health-network.service`; and
- `shapebit-health-greeter.service`.

They start in parallel and are required by `shapebit-health.target`. Stable
ShapeBit wrappers may change their internal Fedora unit mapping without changing
the trial-boot contract. Successful convergence starts the continuous
observation gate before `boot-complete.target` and
`systemd-bless-boot.service`.

Every unit distinguishes a confirmed deterministic failure from an ambiguous
failure. A deterministic failure marks the deployment bad immediately. A
timeout, unavailable device, transient service failure, or insufficiently
classified error leaves the deployment unaccepted and consumes the already
started trial attempt without permanently blocking its digest.

### Identity: 15 seconds

`shapebit-health-identity.service` performs local read-only verification. It
confirms that:

- the booted UKI entry is the expected `trial` entry;
- the mounted deployment has the expected release identity and OCI digest;
- the signed release manifest binds the booted UKI, sealed deployment, and OCI
  artifact according to the contract that D22 will define;
- the release is not locally withdrawn or revoked;
- runtime release identifiers are internally consistent; and
- the Automatic Boot Assessment counter belongs to the booted entry.

It does not require network access or attempt repair. Signature, digest,
artifact-binding, or deployment-identity mismatch is deterministic. A local
verification timeout or unreadable metadata without a classified integrity
failure is ambiguous. The timeout is 15 seconds.

### Storage: 60 seconds

`shapebit-health-storage.service` confirms the expected system LUKS2 and Btrfs
identity, the presence and correct mounting of `@root`, `@state`, `@homes`, and
`@recovery`, and the expected filesystem UUID and subvolume identifiers. It
also confirms that approved writable sentinel locations in `@root` and `@state`
can be synchronized and that the filesystem has not been forced read-only.

The check verifies availability of inactive home-container storage in `@homes`
without activating any user's home. It does not run scrub, destructive repair,
or the still-undecided D08 capacity thresholds. A wrong filesystem identity,
missing structural subvolume, or confirmed structural corruption is
deterministic. Device delay, an unclassified I/O error, or timeout is ambiguous.
The timeout is 60 seconds.

### Critical services: 45 seconds

`shapebit-health-services.service` uses an explicit allowlist rather than
failing on every optional systemd unit. It requires:

- the system D-Bus broker;
- `systemd-logind`;
- `systemd-homed`;
- Polkit;
- the system journal;
- the stable aggregate health endpoint for ShapeBit platform services; and
- the ShapeBit diagnostic-report writer.

Where an API exists, the unit performs a harmless readiness transaction instead
of relying only on `systemctl is-active`: D-Bus must respond, logind must return
seat state, homed must answer without activating a home, Polkit must accept a
non-privileged check, the platform aggregate must report a compatible protocol
and `ready`, and diagnostics must durably write a minimal record in `@state`.
D10 owns the internal platform-service split while preserving this aggregate.

A missing or masked required unit or incompatible required API is deterministic.
A crash, readiness timeout, or temporary unavailability is ambiguous. Optional
Bluetooth, printing, modem, hot-plug, and device-specific services do not gate
acceptance. The timeout is 45 seconds.

### Network stack: 30 seconds

`shapebit-health-network.service` confirms that NetworkManager and
`systemd-resolved` respond, `/etc/resolv.conf` points to the controlled resolver,
loopback and kernel netlink operation are available, and the ShapeBit firewall
policy is loaded. The firewall must retain default inbound denial and agree with
NetworkManager about active profile-scoped exceptions.

Association, Ethernet link, DHCP, an external DNS answer, Internet access, and
any particular removable network device are not required. Failure to load the
required default-deny firewall policy is deterministic. NetworkManager or
resolver readiness timeout is ambiguous. The timeout is 30 seconds.

### Graphical greeter: 90 seconds

`shapebit-health-greeter.service` requires a ready `seat0`, the independent
greeter compositor, the trusted greeter, compatible greeter/login protocol
versions, a successful frame commit and page flip on an active output, locked
pre-authentication state, and PAM-client readiness without a test login.

A closed internal panel is acceptable when an external monitor provides the
active output. With no active output, the unit waits and then reports an
ambiguous timeout. Missing mandatory greeter components or incompatible
protocols are deterministic; driver, output, or page-flip timeout is ambiguous.
The timeout is 90 seconds.

Greeter readiness is latched in volatile state for the boot. A user who logs in
immediately after a successful greeter presentation does not invalidate the
check. User authentication itself is not a health requirement.

### Continuous observation and total deadline

After all five units succeed, every latched condition is monitored for two
continuous minutes. Loss of a condition or restart of a mandatory service resets
the two-minute clock after readiness returns. This permits one self-recovering
service restart without accepting a crash loop.

The complete health phase has a five-minute deadline from the start of the five
parallel controls. If it cannot accumulate two continuous healthy minutes
before that deadline, the result is ambiguous. A deterministic failure at any
point ends the health phase immediately.

### Failure transition

For a deterministic failure, ShapeBit marks the deployment bad, synchronizes a
minimal diagnostic report, and restarts into the previous accepted deployment
within at most 10 seconds. Confirmed integrity failure takes precedence even if
a local or SSH session has already started.

For an ambiguous failure, the deployment remains unaccepted but is not locally
blocked as a bad digest. If no local or SSH user session exists, ShapeBit
synchronizes diagnostics and restarts into the remaining trial attempt after 30
seconds. If any user session exists, ShapeBit does not terminate it. The UI
warns that the deployment is unaccepted, and the user's next restart performs
the remaining attempt. No later deployment is staged until this trial resolves.

After both trial attempts are consumed without durable acceptance, systemd
Automatic Boot Assessment selects the previous accepted entry as defined by
ADR-0007.

## Consequences

- Health checks run concurrently, so their individual limits do not add
  serially during a normal boot.
- Stable wrapper units isolate the acceptance contract from Fedora service-name
  churn.
- A single self-recovering restart may still lead to acceptance, while the
  five-minute cap bounds crash-loop behavior.
- Optional or absent hardware does not roll back an otherwise healthy release.
- Confirmed integrity and structural failures prioritize rollback over unsaved
  session work; ambiguous failures preserve an active session.
- D22 and D10 must satisfy the identity-binding and platform-health interfaces
  referenced by this contract before implementation can be considered complete.

## Boundaries

This ADR owns mandatory boot-health unit names, checks, timeouts, observation,
and failure transitions. ADR-0007 owns trial attempts, blessing, deployment
selection, and previous-deployment retention. ADR-0003 owns the structural Btrfs
layout. ADR-0021 owns ordinary network behavior and firewall policy. D10 owns
platform-service APIs, and D22 owns artifact binding.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0021](ADR-0021-network-ownership-and-privacy.md)

## References

- [systemd Automatic Boot Assessment](https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/)
