# ADR-0038: Installer Disk Identity and Confirmation

**Status:** Accepted

**Date:** 2026-08-13

## Context

The initial installer erases one complete selected disk. Linux device names
such as `/dev/nvme0n1` are enumeration results, not persistent identities, and
can change when storage is attached, removed, or rediscovered. A plan and its
destructive confirmation must therefore remain bound to the actual device the
user reviewed, including when the target is external or lacks a reliable serial
number.

## Decision

### Disk identity record

The privileged backend creates an opaque disk identifier from a captured
identity record. The record contains every available authoritative hardware
property and the display properties needed for confirmation:

- udev stable storage identifiers, preferring WWN where available;
- hardware serial number;
- model;
- exact byte capacity;
- transport or bus type;
- internal, external, or removable classification; and
- current kernel device path for display and access only.

The kernel path is never identity evidence. Before accepting a plan, issuing a
confirmation, and crossing the destructive boundary, the backend resolves the
opaque identifier again and compares the complete required record.

A changed stable identifier, serial number, exact capacity, transport class, or
internal/external/removable classification returns `disk-changed` and clears
selection and confirmation. A disk with conflicting identifiers, ambiguous
multipath presentation, read-only media, or active use that cannot be safely
released is ineligible in the initial installer.

Some devices expose neither a trustworthy WWN nor serial. They remain eligible
only when the remaining composite identity is unique in the current scan and
continues to match. The UI marks the identity as incomplete and requires a
separate acknowledgement on the final screen. This is a usability concession,
not a claim of stable identity across arbitrary hardware rearrangement.

### Eligible targets

The initial installer may target an internal disk or an eligible external USB,
Thunderbolt, or eSATA disk. External and hardware-removable targets are clearly
labelled. They must meet the same minimum capacity and ordinary validation as an
internal disk.

The storage device containing or backing the running installer environment is
never eligible. Neither are read-only devices, ambiguous multipath devices, or
targets with mounts, swap, holders, or other active use that the backend cannot
prove safe to release before confirmation.

An external or removable target adds a separate acknowledgement that disconnect
during installation can leave the disk incomplete and disconnect afterward
prevents ShapeBit from booting. No target is preselected.

### Final destructive confirmation

Immediately before `creating-storage`, the frontend shows one final screen with:

- ShapeBit OS as the system to install;
- disk model and exact human-readable capacity;
- serial number when available;
- internal, external, or removable classification; and
- an explicit statement that the complete disk and all its data will be
  irreversibly erased.

The user must select **I understand that all data on this disk will be
deleted** before enabling **Erase disk and install ShapeBit**. The installer does
not require typing a model, serial, `ERASE`, or another confirmation phrase.

An incomplete hardware identity or external/removable target requires its
additional acknowledgement on the same screen. These acknowledgements do not
replace the ordinary destructive checkbox.

The backend, not the UI, issues a one-use confirmation token bound to the exact
disk identity record, capability scan, plan, target release digest, and active
backend instance. It expires after 10 minutes. Any mismatch, expiry,
disconnection, or backend restart invalidates it. The token authorizes only the
single transition into `creating-storage` for that transaction and cannot be
replayed.

### Stale plan and rescan rules

The capability snapshot and disk selection become stale when:

- any storage device is attached or removed;
- any selected-disk identity or eligibility property changes;
- the selected disk becomes mounted, active, read-only, or otherwise in use;
- the target ShapeBit digest changes;
- required UEFI, Secure Boot, or TPM2 availability changes;
- the privileged backend restarts; or
- the user changes the selected target.

An unrelated monitor, input device, or network-state change does not make the
disk plan stale. Dynamic Wi-Fi results remain outside the storage snapshot as
defined by ADR-0035.

When a plan becomes stale, the installer preserves unrelated safe form values,
including locale, time zone, keyboard choice, computer name, and first-owner
names. It clears the disk selection and every destructive acknowledgement and
token. The user must rescan, select the target again, and repeat final
confirmation.

The backend performs one final identity, eligibility, and active-use check
after consuming the confirmation token and immediately before the first
destructive write. A failure performs no destructive operation.

### Interrupted installations

A valid ADR-0037 transaction journal identifies an already modified target with
the same disk identity record. Continuing that exact transaction does not ask
the user to authorize the original erase again, but it revalidates identity and
every completed checkpoint. Choosing **Start over**, losing reliable target
identity, or lacking a valid journal requires a new scan and final destructive
confirmation.

## Consequences

- Device enumeration changes cannot silently redirect a confirmed erase to a
  different disk.
- The confirmation screen remains readable and does not rely on ritual text
  entry.
- Hot-plugging any storage device intentionally invalidates the selection,
  which is conservative but may require repeating the final step.
- External installation remains possible, with its disconnect risk made
  explicit.
- Devices without stable identifiers remain usable under a visibly weaker,
  current-scan-only identity rule.
- A backend restart cannot reuse an old destructive authorization.

## Boundaries

This ADR owns target-disk identity, eligibility checks related to identity and
active use, external-target warnings, final destructive confirmation, token
expiry, and stale-plan behavior. ADR-0016 owns whole-disk installation and the
storage profile. ADR-0035 owns the capability and plan envelopes. ADR-0037 owns
transaction phases, interruption, and continuation after destruction.

## Related decisions

- [ADR-0010](ADR-0010-dioxus-installer.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0035](ADR-0035-minimal-installer-protocol.md)
- [ADR-0037](ADR-0037-installer-transaction-lifecycle.md)
