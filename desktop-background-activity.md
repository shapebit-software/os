# Background Activity

Background Activity represents long-running work such as downloads, file
copies, updates, and assistant actions without turning every progress change
into a notification. This document records intended behavior, not implemented
or verified desktop behavior.

## System-bar surface

- A Background Activity indicator appears on the right side of the system bar
  only while work is active or paused, or when recent completion or failure
  needs attention. It disappears when nothing remains relevant.
- The indicator opens one global activity panel. A click opens it on that
  indicator's display; the keyboard shortcut uses the focused window's display.
  Only one panel is visible at a time.
- Clicking outside, pressing Escape, or clicking the indicator again closes the
  panel without cancelling or dismissing work.
- An activity tied to a specific application window also shows compact progress
  or status on that application's icon in the relevant
  [Workspace](desktop-workspaces.md). The global panel retains the complete
  activity entry.

## Activity controls and results

- The panel presents **Active/Paused**, **Failed**, and **Recently completed**
  sections in that order. Entries are grouped by owning application or system
  service within each section.
- Activating an application entry switches to and focuses its related window
  when one exists, without moving it between Workspaces. A system-service entry
  opens its relevant details surface.
- Pause, Resume, and Cancel appear only when the owning application or service
  explicitly supports that operation. ShapeBit does not imply that every task
  can be controlled or interrupted.
- A successful activity remains as a recent completed entry for a configurable
  short period and marks the activity indicator. It does not create a banner by
  default, although an application may explicitly request an ordinary
  completion [notification](desktop-notifications.md).
- A failed activity remains until handled or dismissed and produces an ordinary
  banner by default. Only the verified critical-system path defined by
  [Media, Privacy, and Notification Policy](desktop.md) may bypass Do Not
  Disturb.
- An assistant action appears in Background Activity only after it exceeds a
  short-duration threshold or becomes paused. Its activity entry and chat action
  card are two views of the same task, not duplicate execution.
- ShapeBit does not promise that activities survive logout or restart. Only an
  owning service that explicitly supports continuation may resume a task;
  otherwise the owner reports it as interrupted or removes it.
