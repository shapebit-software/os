# ShapeBit Desktop Goals

**Status:** Draft

This document defines the intended product outcomes for ShapeBit Desktop. It
does not prove implementation, replace the ShapeBit OS roadmap, or override an
architecture decision record (ADR).

## Product vision

ShapeBit Desktop should organize the user's activities and working materials,
not merely display applications. It should reduce window overload, context
switching, forgotten work, notification interruption, and information scattered
across applications while remaining compatible with ordinary Wayland clients.

The desktop should feel calm when idle, reveal controls when they are needed,
and preserve the user's spatial and task context across ordinary interruptions.

## Constraints

The desktop goals must be implemented within the accepted ShapeBit OS
architecture:

- A minimal compositor owns Wayland objects, outputs, input, and authoritative
  lock state.
- The shell is a separately restartable, unprivileged process.
- The greeter, lock UI, and authorization agent are separate trusted processes.
- Privileged policy belongs to narrow system services exposed through versioned
  D-Bus interfaces, not to the shell or Settings.
- PipeWire, WirePlumber, portals, logind, NetworkManager, and other suitable
  upstream interfaces remain visible dependencies rather than being renamed by
  unnecessary ShapeBit wrappers.
- The initial application scope is native Wayland; XWayland is deferred.
- Ordinary Wayland applications receive core Workspace and window behavior
  without ShapeBit-specific support. Richer state is used only when exposed by
  a trustworthy application interface.
- A shell failure preserves applications and authoritative lock state. A
  compositor failure ends the damaged graphical session as defined by
  ADR-0018; arbitrary application state is not promised recovery.
- Every essential pointer or touch operation has a keyboard-accessible
  equivalent. Interaction does not depend only on color, animation, hover, or
  precise pointer movement.

The owning decisions are
[ADR-0018](adr-0018-desktop-session-and-authorization.md),
[ADR-0019](adr-0019-display-power-and-thermal-policy.md),
[ADR-0020](adr-0020-media-privacy-and-notifications.md),
[ADR-0023](adr-0023-application-platform-and-system-set.md),
and
[ADR-0030](adr-0030-platform-service-api-contract.md).

## Goals

### G1. Organize windows around Workspaces

A **Workspace** is a persistent user-facing surface that groups windows and
their compositor-owned layout. Workspaces are unnamed by default and arranged
in a horizontal sequence. The detailed lifecycle, optional naming, switching,
deletion, multi-display, and window-admission rules are defined in
[Workspaces](desktop-workspaces.md).

ShapeBit restores Workspace membership and layout. Application content and
sessions are restored only when the application provides reliable support.

The initial product has one hidden **Project** containing all Workspaces.
Projects are reserved for a future feature that may store groups of Workspaces
and other related material; no user-facing Project hierarchy exists initially.
Workspaces do not initially own files, Shelf contents, notifications, tasks,
focus rules, or background operations. Those integrations will be designed
separately.

### G2. Make window organization predictable and reversible

Ordinary Wayland windows may be **tiled**, **stacked**, or **floating**. Tiling
is the default. Floating is reserved for transient windows or an explicit
placement choice. Presentation may be normal, expanded, or fullscreen.
Keyboard focus is independent of both placement and presentation.

Detailed insertion, resizing, collapsed-state, floating, and presentation
rules are defined in [Window Management](desktop-window-management.md).

A tiled window may be **collapsed** into a compositor-owned spine on the
Workspace surface. Adjacent tiles temporarily receive its space. Restoring the
window returns its previous size and restores the adjacent layout.

Expanding a window temporarily fills the usable Workspace area without changing
its saved layout. Fullscreen also hides desktop chrome. One action restores the
previous presentation.

A hidden or inactive window must not raise itself unexpectedly. Attention,
completion, and failure should be indicated without replacing the active
window. Modal and child-window behavior must remain understandable and safe.

### G3. Make stacks a first-class compositor primitive

A stack is one tiled region containing several windows, with one visible member.
Switching members does not change the region's size or surrounding layout.
Inactive members remain running but may suspend repainting. Closing the visible
member removes only that member; a stack with one remaining window becomes an
ordinary tile.

### G4. Navigate through one Overview

The Overview shows Workspaces, their windows and stacks, and applications. It is
used to create or switch Workspaces, focus an existing window, and launch an
application into the selected Workspace. Search initially covers only those three
object types.

Launching never moves an existing window between Workspaces implicitly. Broader
search, actions, archival controls, and the exact visual
arrangement will be designed later.

### G5. Keep permanent chrome minimal and truthful

A compact system bar remains visible during normal, collapsed, and expanded
presentations and hides during fullscreen. It shows access to Overview and the
global assistant, active privacy indicators, essential device status, and time.
It is not a global taskbar or permanent application launcher: application
icons represent only windows that already exist inside each Workspace. The
Workspace sequence has a persistent graphical representation integrated into
the system bar.
The Workspace strip is centered and repeated on every display; the other bar
contents remain grouped to its left and right.

The bar is placed at the bottom by default. One per-user setting can move it to
the top on every display. It has no automatic-hide mode initially; it hides only
on a display where fullscreen presentation is in the foreground. While visible,
it reserves screen space so tiled and expanded windows never sit underneath it.
A Shelf preview or full Shelf replaces a system bar on the same configured
edge; a bar on another edge remains visible.

The [Shelf](desktop-shelf.md),
[assistant chat](desktop-assistant-chat.md), and
[voice interaction](desktop-voice-interaction.md) have separate interaction
designs. Banner, notification-center, and attention routing are defined in
[Notifications](desktop-notifications.md). Background-activity behavior is defined in
[Background Activity](desktop-background-activity.md). Fast system controls are
defined in [Quick Settings](desktop-quick-settings.md). Exact bar styling remains
deferred.
