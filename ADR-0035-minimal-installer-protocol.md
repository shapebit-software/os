# ADR-0035: Minimal Installer Protocol

**Status:** Accepted

**Date:** 2026-08-12

## Context

The unprivileged Dioxus frontend and privileged installer backend need one
testable local protocol. The initial installer has one accepted storage profile
and should exchange user choices rather than encode partitioning, encryption,
or command sequences supplied by the UI. Its protocol must also support a mock
backend without carrying credentials or recovery material in ordinary messages.

## Decision

### Transport and common messages

The ordinary installer protocol uses JSON Lines over a private local Unix
socket. Each line is one complete JSON object. The socket does not listen on a
network interface, and the backend verifies the frontend's Unix peer
credentials before accepting requests. A mock backend uses the same serialized
messages.

A successful request, response, or event has at least:

```json
{"version":1,"message":"installer.writing-system","payload":{"progress":42}}
```

An error has no `message` field and has at least:

```json
{"version":1,"code":"disk-changed","payload":{"disk_model":"Example NVMe"}}
```

`message` and `code` are stable strings. `payload` is always an object, even
when empty. UI text is localized from `message` or `code`; the backend does not
make arbitrary English error text part of the contract. Payloads contain only
data safe for the unprivileged UI. Raw command output, full logs, passwords,
recovery keys, and other secrets are excluded.

The whole ordinary protocol has one integer major `version`. Optional fields
may be added within version 1 and unknown optional fields are ignored. Removing
a field, changing its meaning, or making an optional field mandatory requires
version 2. Unsupported versions return `unsupported-version`. Individual
messages, event groups, and error codes do not carry separate versions.

### Minimal InstallationPlan

The `InstallationPlan` payload contains only choices made by the user:

- the capability-scan identifier;
- the opaque identifier of one disk returned by that scan;
- locale, time zone, and keyboard layout identifiers advertised by the backend;
- computer name;
- first-owner user name and display name; and
- an optional installer-created Wi-Fi profile identifier with
  `save_for_owner`.

It contains no password, Wi-Fi credential, recovery key, derived secret,
partition layout, encryption algorithm, Btrfs detail, command, transaction
state, or recovery acknowledgement. The backend derives those technical
details from accepted ShapeBit policy and validates the complete effective plan
before any destructive action. ADR-0038 owns exact disk identity and final
confirmation; ADR-0036 owns secret transfer; ADR-0037 owns execution state.

### Capabilities

One `Capabilities` response describes the backend snapshot used to build a
plan. It contains:

- protocol version and a fresh opaque scan identifier;
- installer and target ShapeBit release version and digest;
- disks with opaque identifier, display model, capacity, eligibility, and a
  stable blocking-reason code when ineligible;
- availability of UEFI, Secure Boot, and TPM2;
- current Internet connectivity;
- available Wi-Fi adapters and whether scanning is possible; and
- supported locale, time zone, and keyboard-layout identifiers.

The visible Wi-Fi network list is dynamic and is requested separately; it is
not frozen into `Capabilities`. A plan references the capability scan that
produced its choices. The backend rejects it as `stale-capabilities` when the
relevant environment no longer matches and requires a new scan.

### Optional installer Wi-Fi

When no working Internet connection exists, the frontend offers a Wi-Fi step.
The user may connect or skip it; lack of Internet does not block installation.
The selected password uses the ADR-0036 secret channel and never enters the
ordinary protocol, plan, event stream, or logs.

An installer-created connection is temporary in the live environment. If the
plan requests preservation, the backend saves it after provisioning as a
profile owned by the first user inside that user's encrypted home, not as an
automatic pre-login system profile.

When Internet already works, the installer does not interrupt the flow with a
mandatory network screen. It preserves a Wi-Fi profile only when that profile
was created by the installer. It does not silently copy credentials inherited
from an external live, laboratory, or provisioning environment.

### Installation events

An `installation-event` message places these fields in its payload:

- transaction identifier;
- monotonically increasing sequence number;
- current step identifier;
- event kind;
- event-specific data such as optional progress from 0 through 100.

The event kinds are:

```text
step-started
progress
warning
step-completed
installation-failed
```

Each ordinary event still uses the common `message` plus `payload` envelope.
The message is a localization key. The sequence number defines ordering; UI
arrival time does not. ADR-0037 defines step names, reconnection, replay, and
transaction completion.

### Installer errors

An error consists only of the common `version`, string `code`, and object
`payload`. The initial codes are:

```text
unsupported-version
invalid-plan
stale-capabilities
disk-changed
insufficient-space
network-unavailable
secret-unavailable
integrity-failure
operation-failed
cancelled
internal
```

Clients must handle an unknown code as a generic failure. A payload may provide
safe structured context, but never a second free-form `message` or sensitive
diagnostic detail. Full technical evidence belongs to the local diagnostic
report under ADR-0031.

## Consequences

- The plan remains small because it expresses product choices instead of disk
  implementation steps.
- One capability snapshot avoids many partially inconsistent probe requests,
  while Wi-Fi scan results remain appropriately dynamic.
- JSON Lines is easy to inspect and mock without introducing HTTP, JSON-RPC, or
  D-Bus into the initial installer.
- One protocol version and common envelopes keep compatibility rules simple.
- The backend remains responsible for validating every choice; possession of a
  syntactically valid plan is not authorization for disk destruction.
- Wi-Fi setup improves first use without making installation depend on Internet
  access or leaking credentials into the serializable plan.

## Boundaries

This ADR owns the ordinary installer transport, envelope, versioning,
InstallationPlan choices, Capabilities snapshot, optional Wi-Fi behavior,
event shape, and error shape. ADR-0010 owns the Dioxus/frontend privilege
boundary. ADR-0036 owns the secret channel. ADR-0037 owns transaction semantics.
ADR-0038 owns disk identity and destructive confirmation. ADR-0039 owns
Recovery Kit presentation and lifecycle.

## Related decisions

- [ADR-0010](ADR-0010-dioxus-installer.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0021](ADR-0021-network-ownership-and-privacy.md)
- [ADR-0031](ADR-0031-diagnostic-reports-and-consent.md)
- [ADR-0036](ADR-0036-one-shot-installer-secret-channel.md)
- [ADR-0037](ADR-0037-installer-transaction-lifecycle.md)
- [ADR-0038](ADR-0038-installer-disk-identity-and-confirmation.md)
- [ADR-0039](ADR-0039-recovery-kit-presentation-and-lifecycle.md)
