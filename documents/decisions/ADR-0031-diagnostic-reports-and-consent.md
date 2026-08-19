# ADR-0031: Diagnostic Reports and Consent

**Status:** Accepted

**Date:** 2026-08-12

## Context

ShapeBit must preserve useful evidence after boot, update, storage, service, and
desktop failures. Those reports can contain detailed operational context,
including logs, paths, user names, hardware, and network information. The
system needs bounded local retention, an explicit device-wide choice for
automatic upload, and practical exclusion of high-risk secrets without
claiming that arbitrary logs can be perfectly anonymized.

Minimal rollout telemetry under ADR-0009 remains a separate mechanism and
setting.

## Decision

### Report envelope and payload ownership

All reports use one common envelope. It contains only:

- envelope format version;
- random report identifier and creation time;
- producing component and its interface version;
- event type and severity;
- ShapeBit release identity and deployment digest; and
- payload media type and producer-owned payload-schema version.

There is no common detailed payload schema. Each producer owns and versions its
payload, including any structured records or attachments needed for its event.
The diagnostics service validates the common envelope and packages the payload
without interpreting it as one universal system dump.

Producers collect only fields and log sources declared for their report type.
ShapeBit does not automatically attach the complete journal, a home directory,
a file listing, a memory dump, or other broad ambient state merely because it
is available.

### Practical data protection

A detailed report may contain information useful for diagnosis, including:

- selected system logs;
- hardware models, drivers, and firmware details;
- process and service names;
- system and home paths;
- relevant network configuration and addresses;
- user names that occur in approved logs; and
- boot, update, transaction, and failure-stage history.

The following content is always prohibited:

- passwords and Recovery Kit material;
- private cryptographic keys;
- recognized authentication tokens, cookies, and session secrets;
- deliberately collected contents of private user documents;
- clipboard contents, screenshots, and audio or video capture; and
- form contents or text observed while the user types.

Producers must not open an ordinary user file solely to include its content.
Selected system logs remain allowed even though they can incidentally contain
user-supplied text. ShapeBit applies format-aware filters for known secret
fields and patterns, but does not promise perfect recognition of every secret
that another component may have written into a log. The global-consent UI
describes the allowed data categories and this residual risk.

### Global upload consent

Detailed reports are always created and retained locally regardless of upload
consent. Automatic upload is disabled by default and controlled by one
device-wide setting. Only an active local administrator may change it through
the normal Polkit authorization flow.

Enabling the setting applies to reports created from that point onward. Reports
are then uploaded automatically without a per-report prompt and without a
content preview. Reports created before consent are not uploaded retroactively.

When consent is enabled, ShapeBit creates a random diagnostic installation
identifier. It is not derived from a hardware serial, TPM identity, MAC address,
user account, or other existing identifier. It lets the service correlate
reports from one installation and is visible in Diagnostics settings.

Disabling consent stops future upload, discards unsent outbound copies, and
deletes the local diagnostic installation identifier. It does not delete local
source reports or retract reports already received by the server. Re-enabling
consent, resetting the device, or reinstalling ShapeBit creates a new identifier.

### Local retention

An ordinary local report expires 30 days after creation. The total ordinary
report store is limited to 2 GiB; when necessary, the oldest reports are removed
first. Successful upload does not shorten local retention.

A report attached to an unresolved active failure is protected from automatic
deletion. After the failure resolves, ordinary age and capacity rules apply. If
protected reports prevent compliance with the 2 GiB limit, ShapeBit preserves
them, rate-limits or deduplicates new equivalent reports, suppresses lower-
severity additions, and warns the administrator instead of deleting the active
evidence.

An administrator may explicitly delete all local diagnostic reports. Report
producers must rate-limit repeated failures and coalesce equivalent occurrences
so that a crash loop does not create an unbounded number of reports.

### Server retention

The ShapeBit diagnostic service retains each full detailed report and its
diagnostic installation identifier for 90 days, then deletes both. It does not
retain the transport source IP address as diagnostic data or in a long-term
request log. Access to raw reports is restricted to the ShapeBit diagnostic
operator.

ShapeBit may retain derived aggregate statistics longer than 90 days only after
removing the diagnostic installation identifier, user names, paths, network
addresses, and free-form log text. Those aggregates are no longer treated as
full diagnostic reports.

### Manual export

An active local administrator may export one report or a selected time range
regardless of the global upload setting. Selecting **Export** is the explicit
local-file action; ShapeBit shows no content preview.

The result is a standard `.tar.zst` archive containing common envelopes,
producer payloads, and a checksum manifest. It is created with permissions for
the exporting user only and is not encrypted by default. The UI warns that the
archive may contain logs, user names, paths, hardware details, and network data.
The same prohibited-content and known-secret filtering rules apply to export.

Reading or importing an archive never executes a contained program, script,
plugin, hook, or other payload code.

## Consequences

- One global choice enables useful automatic fault correlation without repeated
  consent dialogs.
- Users cannot inspect each report before upload and accept a stated residual
  risk that approved logs contain unexpected sensitive text.
- Component-owned payloads can evolve independently, while the common envelope
  keeps indexing and transport stable.
- Bounded local and server retention limits long-term accumulation.
- Active-failure evidence takes precedence over the ordinary local capacity
  limit, requiring producer rate limiting and low-space warnings.
- Manual archives remain compatible with standard tools but require careful
  handling because they are not encrypted by default.

## Boundaries

This ADR owns the common diagnostic envelope, producer payload boundary,
prohibited content, global detailed-report consent, diagnostic installation
identifier, local and server retention, and manual export. ADR-0009 owns minimal
rollout telemetry. ADR-0028 owns general capacity and low-space behavior.
ADR-0030 owns the diagnostics service API and job lifecycle. Individual domain
ADRs determine when a report is mandatory and which event-specific evidence is
useful.

## Related decisions

- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0009](ADR-0009-staged-rollout.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
- [ADR-0028](ADR-0028-capacity-and-low-space-policy.md)
- [ADR-0030](ADR-0030-platform-service-api-contract.md)
