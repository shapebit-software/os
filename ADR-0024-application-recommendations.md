# ADR-0024: Application Recommendations

**Status:** Accepted

**Date:** 2026-08-09

## Context

The ShapeBit application UI exposes the full supported catalog while also
offering a much smaller curated recommendation list. A recommendation is a
stronger product signal than catalog availability, but the project is currently
managed by one person and must not invent a multi-person approval process that
does not exist.

## Decision

### Authority and change record

The ShapeBit project owner is the sole curator and approver of the
recommendation list. No vote, second reviewer, or external approval is required.
Every addition, removal, ordering change, or category change has a short public
rationale in the repository history.

Automation may identify maintenance, permissions, ownership, availability,
license, or security changes and present a report. It never changes the list or
approves a recommendation. The approval model may be replaced only after the
project actually has a team and a new ADR defines its authority.

### Inclusion criteria

A recommended application must:

- run natively on the supported Wayland-only ShapeBit desktop;
- come from Flathub or an integration accepted under ADR-0023;
- identify the software author, package maintainer, and binary source
  accurately;
- be actively maintained and have a credible path for security fixes;
- request permissions proportionate to its advertised function;
- pass installation, launch, update, and removal checks on the current stable
  ShapeBit release;
- have no unresolved license or branding issue known to ShapeBit; and
- provide clear user value, even when a competing application is also listed.

Flathub publisher verification is not mandatory. A community-maintained package
may be recommended when its community status and actual source remain visible.
Paid promotion does not determine inclusion.

### Re-review

There is no calendar-based re-review interval, expiry date, or automatic stale
status. The curator initiates a review at their discretion or in response to a
specific signal. Relevant signals include project abandonment or transfer,
loss of Wayland support, a material permission expansion, a security incident,
source disappearance, and a license or business-model change.

Automation may report these signals but does not interpret silence or elapsed
time as a removal decision.

### Removal

Removal from recommendations requires the curator's decision and a short public
rationale. It removes only the recommendation signal. ShapeBit does not
automatically uninstall the application or delete its data, and an existing
installation continues to receive updates from its configured source.

When the reason is a serious known security risk, ShapeBit may warn users who
have the application installed. Blocking execution, revoking a package, or
forcing removal is outside the recommendation mechanism and requires a separate
security authority and decision.

### Signed manifest and presentation

Recommendations are distributed as a small signed manifest independently of
the OS image. It records at least the application ID, source, category, manual
position, attribution and verification information, license, and short
rationale. Exact serialization and production key operations belong to the
release-manifest and signing work in D21-D23.

The system automatically retrieves a newer manifest. A valid signed manifest
atomically replaces the current one. Download, parsing, or signature failure
keeps the last valid manifest; ShapeBit never falls back to unsigned data. The
OS image contains an initial signed copy so the recommendation view works before
its first refresh. Updating this manifest neither installs nor removes an
application.

There is one canonical list for all users. The curator manually defines
categories and ordering. ShapeBit does not personalize recommendations from
telemetry, launch history, country, or account profile. Flathub popularity or
ratings may be displayed as external information but do not reorder the list.
Installed applications remain visible with an installed marker. The complete
catalog remains searchable, and there is no fixed maximum list length.

## Consequences

- Governance matches the project's actual one-person maintenance model.
- Every recommendation remains an explicit human decision with a public reason.
- The absence of a mandatory review interval reduces process overhead but can
  leave a stale recommendation until the curator or automation notices a
  relevant change.
- A signed independently refreshed list permits fast recommendation removal
  without an OS release.
- Recommendation removal is not confused with remote application control.

## Boundaries

This ADR owns recommendation authority, inclusion, re-review, removal,
distribution behavior, ordering, and personalization. ADR-0023 owns application
sources, installation, updates, permissions, and runtime support. D21-D23 own
the manifest serialization and production signing system. A future application
revocation policy is separate from recommendations.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0009](ADR-0009-staged-rollout.md)
- [ADR-0023](ADR-0023-application-platform-and-system-set.md)
- [ADR-0042](ADR-0042-production-signing-operations.md)
