# Notifications

ShapeBit notifications provide visible but non-focus-stealing attention across
[Workspaces](desktop-workspaces.md). This document records intended behavior,
not implemented or verified desktop behavior. Privacy, lock-screen, sharing,
critical-notification, and Do Not Disturb constraints remain owned by
[Media, Privacy, and Notification Policy](desktop.md).

## Notification panel

- One global notification panel opens from an indicator on the right side of
  the system bar. A click opens it on that button's display; a keyboard shortcut
  uses the focused window's display. Only one panel is visible at a time.
- Clicking outside, pressing Escape, or clicking the indicator again closes the
  panel without clearing notifications.
- Notifications are grouped by application. Groups are ordered by newest
  activity, and notifications are newest-first within each group. A group shows
  its newest notification initially with a count and expands to reveal older
  items.
- The indicator badge counts unseen notifications. Opening the panel marks the
  notifications currently listed as seen without dismissing them.
- The panel header contains a **Do Not Disturb** toggle. Secondary-clicking the
  indicator exposes the same quick toggle; schedules are configured in Settings.
- Undismissed notifications persist locally across logout and restart, subject
  to a configurable retention period.

## Workspace routing

- A notification that identifies a window belongs to that window's Workspace.
- Without a window association, a notification belongs to the application's
  Workspace when all of that application's windows are in one Workspace.
- When an application spans several Workspaces, or has no window, an
  unassociated notification is global. It does not mark every Workspace and its
  banner appears on the focused window's display by default.
- An ordinary notification belonging to the active Workspace shows a brief
  non-focus-stealing banner by default. A notification belonging only to an
  inactive Workspace is queued without a banner and marks its application icon
  and Workspace segment instead. Per-application settings may allow its banner.
- Banner behavior has a global per-user default and per-application overrides.

Notification markers and application attention requests are separate. Seeing a
notification in the panel clears its notification marker; focusing its related
window may also clear it. A window attention request remains until the window is
focused or the application withdraws that request.

## Banners

- Banners appear beside the notification indicator: upward from a bottom bar
  or downward from a top bar. With the bar hidden by fullscreen, they use the
  same configured corner where the indicator normally appears.
- At most three ordinary banners are visible at once. Additional notifications
  go directly to the center until space becomes available.
- Ordinary banners close after a configurable short duration. Hover or keyboard
  focus pauses the timer, and the notification remains in the center afterward.
- Verified critical system notifications remain visible until explicitly
  handled or dismissed.

## Dismissal and policy

- Activating a notification body invokes its application-provided default
  action. A window target switches to that window's Workspace and focuses it
  without moving it.
- Inline notification actions leave the panel open. An action that opens or
  focuses an application window closes the panel automatically.
- A banner close control dismisses the notification from both the banner and
  center. Automatic banner timeout hides only the banner.

- Dismissing one ordinary notification, dismissing an application group, and
  **Clear all** act immediately without confirmation and offer a brief Undo.
- **Clear all** excludes unresolved critical system notifications, which must be
  handled or dismissed individually.
- Do Not Disturb queues ordinary application notifications. Applications cannot
  bypass it; only the verified critical system path defined by [Media, Privacy, and Notification Policy](desktop.md) can.
- Fullscreen alone does not enable Do Not Disturb. Whole-monitor sharing,
  locking, unlock summaries, and critical-system exceptions follow [Media, Privacy, and Notification Policy](desktop.md).
