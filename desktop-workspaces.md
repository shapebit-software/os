# Workspaces

**Status:** Draft

Workspaces are persistent user-facing surfaces that group windows and
compositor-owned layout across all connected displays. This document records
intended behavior, not implemented or verified desktop behavior.

## Project container

The initial desktop has one hidden **Project** entity. It contains the user's
Workspaces and is not exposed as a creation, switching, or navigation level.
Projects are reserved as a future extension for storing sets of Workspaces and
other related material. Project names are unique; other future Project behavior
remains undecided.

## Workspace set

- ShapeBit always has at least one Workspace. No Workspace has a special Home
  identity or appearance.
- Workspaces are unnamed by default. A user may assign a name later.
- Non-empty Workspace names are trimmed and unique without regard to letter
  case. An empty name means the Workspace is unnamed.
- A Workspace created through the ordinary creation action starts empty and
  becomes active immediately. Overview and edge-transfer creation are the
  exceptions described below.
- There is no user-facing maximum number of Workspaces. Overview adapts through
  scrolling and search.
- Workspaces form a user-reorderable horizontal sequence.

## Persistent representation

ShapeBit keeps a compact graphical representation of the Workspace sequence on
the center of the system bar, between Overview and assistant controls on the
left and privacy, device-status, and time indicators on the right. Every
display's bar shows the same global Workspace strip. It is horizontal, with one
equal-width segment per Workspace in navigation order.

The strip scrolls horizontally within its allotted bar area instead of
shrinking segments and automatically keeps the active Workspace visible.
Scrolling over an overflowing strip moves its viewport without switching the
active Workspace; switching remains an explicit click, shortcut, or dedicated
gesture.

- The active Workspace segment is highlighted. Other segments remain subdued
  but visible.
- Pointer hover shows a tooltip only; it never previews or switches the
  Workspace.
- An unnamed empty Workspace has no generic icon. Its boundary and state are
  the only visible content. Tooltips and accessibility interfaces identify it
  by its current position, such as **Workspace 2**; that is not a persistent
  name.
- A user-assigned Workspace name appears before its application icons and is
  truncated when necessary. Its tooltip exposes the complete name.
- Users can reorder Workspaces by dragging their segments. An equivalent
  keyboard-accessible reorder command is required, and the spatial order
  changes immediately. Reordering does not activate another Workspace or alter
  windows. Keyboard focus follows the moved segment so repeated commands keep
  moving the same Workspace.
- A segment's secondary-click menu initially contains **Rename** and **Delete
  Workspace**. Deletion follows the rules below.
- **Rename** opens a popover anchored to the segment rather than editing the
  segment itself. Valid edits apply automatically; there are no Save or Cancel
  actions. A duplicate name is shown as invalid input and does not replace the
  last valid name. Clicking outside, pressing Escape, or using the close
  control closes the popover while keeping the latest valid value. Clearing the
  field returns the Workspace to its unnamed state.
- A trailing **+** control creates a new unnamed Workspace at the end and
  switches to it immediately. It appears when the pointer hovers anywhere over
  the strip or when keyboard focus enters the strip. A keyboard command and
  accessibility interface expose the same action without depending on hover.
- On touch, a long-press reveals the creation and segment-management controls,
  which remain visible until the user taps outside the strip. Long-pressing a
  segment and dragging reorders it; long-pressing and releasing without movement
  opens its Rename/Delete menu.

Each application with a window in a Workspace appears once as an icon, with a
count badge when it has multiple windows. Icons retain first-appearance order
instead of moving with focus. An icon disappears when its application's last
window leaves or closes; background applications without windows do not appear.
Application icons are not draggable between Workspace segments in the initial
design; individual-window and complete-stack transfer controls remain the
unambiguous movement mechanisms.

- The focused application's icon has a stronger highlight inside the active
  Workspace.
- Clicking an application icon in an inactive Workspace switches to that
  Workspace and focuses the application's most recently used window, restoring
  a collapsed window or selecting its stack member when necessary.
- In the active Workspace, clicking an icon focuses its most recently used
  window. Repeated clicks while that window is focused cycle through the
  application's other windows in recent-use order.
- Clicking empty space in a Workspace segment switches to it without changing
  its remembered window focus.
- When all application icons do not fit, the segment ends with a `+N` overflow
  indicator. Activating it opens a small anchored list without switching
  Workspaces until an application is selected.
- An application attention request marks its icon and its Workspace segment,
  including when the icon is in overflow. It never switches or focuses
  automatically. The marker clears when the relevant window receives focus or
  the application withdraws the request, not merely when its Workspace becomes
  active.

## Strip keyboard navigation

- Left and Right move between Workspace segments; Enter activates the focused
  Workspace.
- Down enters the selected Workspace's application icons. Left and Right move
  between icons, and Up returns to the Workspace-segment level.
- Right from the last Workspace segment moves focus to the trailing **+**
  control. Enter creates and activates a Workspace; Left returns to the last
  segment.
- The `+N` overflow indicator is the final item at the application level. Enter
  opens its hidden-application list, where arrow keys navigate the entries.
- Escape first closes the overflow list, then leaves the application level, and
  finally returns focus to the previously focused window. It does not change
  Workspaces unless the user activated one.

## Overview

- Overview opens as one coordinated mode across every display. Each display
  preserves and presents the windows normally placed there rather than moving
  all thumbnails onto one screen.
- The display whose Overview button was clicked contains the search and
  application controls. The keyboard shortcut uses the focused window's
  display. Other displays participate without duplicating those main controls.
- The default main view prioritizes window and stack thumbnails. The full
  application list opens through a separate **Applications** control, while
  typing searches Workspaces, windows, and applications immediately.
- Each display's compact Workspace strip expands into larger previews in the
  same horizontal order. A preview contains only that display's windows, while
  Workspace selection remains synchronized across all displays.
- The selected Workspace preview expands to show usable window thumbnails;
  inactive Workspaces remain smaller summaries. A single click selects and
  expands a Workspace without leaving Overview. Enter or double-click activates
  it and closes Overview.
- The trailing **+** is always visible in Overview. It creates an unnamed empty
  Workspace and selects it while Overview remains open; creation here does not
  activate the Workspace yet.
- Escape closes Overview and returns to the Workspace that was active when it
  opened, regardless of the current selection. Preview selection alone never
  activates a Workspace.
- Expanded Workspace previews preserve the relative tiled, stacked, collapsed,
  and floating arrangement rather than packing windows into a separate grid.
- A stack appears as one tiled-region preview with its active member visible and
  a row of member icons. Clicking a member selects its preview; Enter or
  double-click focuses it and closes Overview.
- A collapsed region remains a spine in the preview. Selecting it highlights
  the spine; Enter or double-click restores and focuses it, then closes
  Overview.
- Dragging a window preview to another Workspace supports the same two transfer
  modes as the bar and screen edge. A quick drop uses automatic insertion,
  leaves the source selected, and keeps Overview open. Holding over the target
  selects and expands it for exact placement; it remains selected after the
  drop, and Overview stays open.
- The configurable stack-transfer modifier moves the complete stack when a
  member preview is dragged.
- Dropping a window preview on Overview's **+** creates an unnamed target. A
  quick drop creates it in the background and leaves the source selected;
  holding creates and selects it for exact placement.
- A hovered or keyboard-focused window preview exposes a close control; Delete
  is its keyboard equivalent. An unsaved-work prompt appears above Overview,
  and cancelling it leaves Overview open.
- Overview initially selects the active Workspace and presents Workspaces in
  their horizontal order.
- Typing while Overview is open starts search immediately without first
  focusing a search field. Search initially covers Workspaces, windows, and
  applications.
- With a non-empty query, the first Escape clears search and restores normal
  Overview. A second Escape exits Overview and returns to the previously active
  Workspace.
- Activating a Workspace result switches to it and closes Overview.
- Activating a window result switches to its Workspace, restores it if
  collapsed, selects its stack member when necessary, focuses it, and closes
  Overview.
- Activating an application result launches it into the selected Workspace and
  closes Overview. If the application reuses a window elsewhere, the standard
  **Go to window** and **Move window here** notice applies.

## Persistence and switching

- Workspaces persist across logout and restart until explicitly deleted.
- A Workspace remembers its layout and last focused window. Returning to it
  restores both. If the remembered window no longer exists, focus moves to the
  most recently focused remaining window.
- Login restores the Workspace that was active at logout. Missing or invalid
  saved state falls back to the first available Workspace.
- One Workspace spans every connected display. Switching Workspaces changes
  the complete multi-display surface together.
- Previous and next navigation stops at the first and last Workspace rather
  than wrapping.

## Deletion

- Deleting an empty Workspace is immediate and requires no confirmation when
  another Workspace remains. Deletion is unavailable when it would remove the
  final Workspace. In that case the menu item remains visible but disabled and
  explains that ShapeBit requires at least one Workspace.
- Deleting a non-empty Workspace opens a small transient choice window. **Move
  windows to another Workspace** has initial keyboard focus; **Close
  applications** is the secondary action. Other Workspaces are presented as
  graphical destination choices. The nearest Workspace is preselected,
  preferring the left neighbor when one exists and otherwise the right, while
  the user may select any other Workspace. Clicking outside, clicking the close
  control, or pressing Escape cancels the operation. A separate Cancel button
  is not required.
- Moving windows preserves tiled and floating placement, collapsed state,
  stacks, and the transferred tiling layout. The complete tiled layout is
  inserted into the destination Workspace as one subtree using the normal tiling
  insertion rule.
- Closing applications respects their unsaved-work interactions. If any
  application refuses or cancels closure, deletion stops and the Workspace
  remains with any windows that are still open.
- The Workspace is removed entirely only after either transfer or closure
  succeeds.
- Deleting the active Workspace activates its nearest neighbor, preferring the
  left and otherwise the right. Deleting an inactive Workspace leaves the
  current active Workspace and keyboard focus unchanged.
- When closing applications in an inactive Workspace requires an unsaved-work
  interaction, ShapeBit temporarily switches there so the prompt is usable.
  After the close sequence succeeds or is cancelled, ShapeBit returns to the
  previously active Workspace unless that Workspace was the deletion target.

## Window admission

- A normal new window belongs to the active Workspace.
- A dialog or child window remains with its parent. A window created from an
  interaction with an existing window inherits that source window's Workspace,
  even if the user switches Workspaces before creation completes.
- An unsolicited, unparented window joins the application's Workspace when all
  of its existing windows belong to one Workspace. It requests attention
  without switching Workspaces or taking focus.
- When an application has windows in several Workspaces, or has no existing
  window, an unsolicited window joins the active Workspace and remains
  unfocused unless it carries a valid current user-activation request.
- Launching an application from Overview requests a new window in the selected
  Workspace and never moves an existing window implicitly. If the application
  reuses a window in another Workspace, ShapeBit remains in place and offers
  **Go to window** and **Move window here**.
- Moving a member out of a stack moves only that window. The source stack
  reduces normally and becomes a tile when one member remains. The extracted
  member becomes a normal tile; other tiled, floating, and collapsed windows
  preserve their placement state.

## Edge and keyboard transfer

- Dragging a window to the left or right outer edge targets the adjacent
  Workspace in the horizontal sequence.
- A quick drop transfers the window using the target Workspace's normal
  insertion rule while leaving the source Workspace active. Focus in the
  source falls back to its most recently focused remaining window.
- Holding at the edge opens the target Workspace while the drag continues, so
  the user can choose an exact drop position. After that drop, the target
  remains active and the moved window is focused.
- At either outer end of the sequence, a quick drop creates an unnamed
  Workspace in the background on that side. Holding at the edge creates and
  opens an unnamed Workspace on that side during the drag.
- A configurable modifier changes the transfer from the dragged stack member
  to the complete stack. The exact default modifier is deferred.
- With multiple displays, transfer activates only at the outermost left or
  right boundary of the complete display arrangement, not at an edge shared by
  displays.
- Keyboard **Move window left/right** commands mirror a quick edge drop,
  including background creation at either end. Separate commands move the
  complete stack. Exact bindings are deferred.
- Dropping a dragged window on a Workspace segment also transfers it there. A
  quick drop uses automatic insertion and leaves the source active; holding
  over the segment opens the target Workspace for exact placement.
- Dropping on the trailing **+** control creates an unnamed target Workspace.
  A quick drop creates it in the background, while holding opens it for exact
  placement.
- The same configurable modifier transfers the complete stack through either
  bar target. On multiple displays, automatic insertion uses the display whose
  system bar received the drop, targeting its focused tiled region or filling
  it when none exists.

## Display changes

- When a display disconnects, its windows immediately reflow onto the remaining
  displays so that none become unreachable.
- During the current login session, ShapeBit remembers their previous display
  assignments. Reconnecting the same display restores them only if the user
  has not manually rearranged an affected window.
- Manually rearranging an affected window cancels automatic restoration. At
  logout, the reflowed arrangement becomes the saved layout. Separate layouts
  for different display configurations are deferred.
