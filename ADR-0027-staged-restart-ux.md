# ADR-0027: Staged-Restart UX

**Status:** Accepted

**Date:** 2026-08-09

## Context

ShapeBit downloads, verifies, and stages system updates in the background, but
ADR-0007 requires the user to choose when an active session ends. The desktop
therefore needs a predictable way to report that an update is ready without
turning an important maintenance signal into a forced interruption.

## Decision

### Presentation and reminder cadence

When a verified update has been staged successfully, ShapeBit immediately
posts one system notification and adds a persistent, non-intrusive restart
indicator to the system panel. The indicator remains until the pending update
is booted or withdrawn.

If the user has not restarted, ShapeBit sends the first reminder after 24
hours and subsequent reminders every 72 hours. It shows at most one such
notification in a calendar day. Notifications have no sound, are not
full-screen or modal, and do not interrupt the current activity.

ShapeBit does not assign a more intrusive cadence to security updates. Release
withdrawal and revocation remain separate safety mechanisms; this UX does not
classify waiting updates as normal or security-critical.

The user may disable restart-reminder notifications in Settings. This does not
hide the persistent panel indicator or cancel the staged update.

### Notification actions

The notification provides three actions:

- **Restart now** opens a final confirmation that lists active local and SSH
  sessions before requesting the restart;
- **Remind tomorrow** delays the next reminder for 24 hours, after which the
  normal cadence resumes; and
- **Dismiss** closes the current notification without changing the normal
  reminder schedule.

On the lock screen, ShapeBit shows only a generic system message that a restart
is pending. It exposes no actions or update details until the user unlocks the
session. During presentation mode, full-screen activity, or screen sharing,
notification banners are deferred until that state ends; the panel indicator
remains available where the shell can safely present it.

The confirmation warns that ShapeBit cannot guarantee preservation of unsaved
application work. ShapeBit never claims to save, serialize, or restore arbitrary
application state on behalf of applications.

### Restart and shutdown behavior

Every ordinary restart selects the staged deployment for its trial boot. The UI
does not offer a routine "restart without updating" bypass. If another local
user or an SSH session is active, restart requires an additional explicit
confirmation that identifies those active sessions.

Shutting down does not cancel the staged deployment. The next normal power-on
selects it for trial boot. ShapeBit does not schedule unattended overnight or
time-based restarts, terminate a session automatically, or force a restart.

The trial result, remaining attempts, rollback behavior, and treatment of an
unaccepted deployment are governed by ADR-0007 and ADR-0026.

## Consequences

- Users receive a durable maintenance signal without repeated daily
  interruption.
- Disabling reminder banners cannot make a pending update completely invisible.
- A normal restart has one clear meaning when an update is staged.
- Updates may wait indefinitely for a user-controlled restart.
- Active sessions receive an explicit warning, but ShapeBit cannot prevent a
  user from confirming a disruptive restart.
- Shutdown followed by power-on applies the same trial-boot safeguards as an
  immediate restart.

## Boundaries

This ADR owns the desktop presentation, reminder cadence, notification actions,
and the user-facing restart and shutdown behavior for an already staged update.
ADR-0007 owns staging, trial attempts, blessing, deployment selection, and
rollback. ADR-0020 owns general notification privacy. ADR-0026 owns boot-health
evidence and failure transitions after the updated deployment starts.

## Related decisions

- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0020](ADR-0020-media-privacy-and-notifications.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
