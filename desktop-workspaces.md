# Workspaces

**Status:** Draft

Workspaces are persistent user-facing surfaces that group windows and
compositor-owned layout across all connected displays. This document records
intended behavior, not implemented or verified desktop behavior.

## Project container

The initial desktop has one hidden **Project** entity. It contains the user's
Workspaces and is not exposed as a creation, switching, or navigation level.
Projects are reserved as a future extension for storing sets of Workspaces and
other related material. That future behavior remains undecided.

## Workspace set

- ShapeBit always has at least one Workspace. No Workspace has a special Home
  identity or appearance.
- Workspaces are unnamed by default. A user may assign a name later.
- A user-assigned name is trimmed, non-empty, and unique without regard to
  letter case.
- A Workspace created through the ordinary creation action starts empty and
  becomes active immediately. Edge-transfer creation is the exception described
  below.
- There is no user-facing maximum number of Workspaces. Overview adapts through
  scrolling and search.
- Workspaces form a user-reorderable horizontal sequence.

## Persistent representation

ShapeBit keeps a compact graphical representation of the Workspace sequence on
the desktop, with distinct active and inactive states. Every unnamed Workspace
uses the same visual treatment. The representation may use a line with
application text, application icons, or another compact representation. Its
placement, contents, and final visual form remain open design decisions.

## Overview

- Overview initially selects the active Workspace and presents Workspaces in
  their horizontal order.
- Typing while Overview is open starts search immediately without first
  focusing a search field. Search initially covers Workspaces, windows, and
  applications.
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
  final Workspace.
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

## Display changes

- When a display disconnects, its windows immediately reflow onto the remaining
  displays so that none become unreachable.
- During the current login session, ShapeBit remembers their previous display
  assignments. Reconnecting the same display restores them only if the user
  has not manually rearranged an affected window.
- Manually rearranging an affected window cancels automatic restoration. At
  logout, the reflowed arrangement becomes the saved layout. Separate layouts
  for different display configurations are deferred.
