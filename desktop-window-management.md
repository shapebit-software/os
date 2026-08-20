# Window Management

**Status:** Draft

ShapeBit Desktop uses tiling by default while retaining explicit stacking and
floating placement. Placement, presentation, and keyboard focus are separate
properties. This document records intended behavior, not implemented or
verified desktop behavior.

## Tiling insertion and removal

- A new or moved tile is inserted beside the focused tiled region. If focus is
  on a floating window, ShapeBit uses the most recently focused tiled region.
  With no tiled region, the new tile fills the usable work area.
- The focused region is split along its longer dimension. The new tile receives
  half the region and is placed to the right after a horizontal split or below
  after a vertical split. A square region uses the horizontal split.
- A transferred Workspace layout follows the same rule as one intact subtree and
  retains its internal proportions.
- If a new split would violate either window's minimum usable size, the new
  window joins the focused region as a stack instead.
- Closing a tile gives its space to its sibling region while preserving every
  other split ratio.
- Manual boundary resizing persists the changed split ratio in the Workspace
  layout. A boundary stops when it reaches a window's minimum usable size.

## Collapsed tiles and constrained space

- A tiled window can be manually collapsed into a narrow spine at its original
  position. Neighboring content temporarily receives its space. Activating the
  spine restores the saved tile size and focuses the window.
- Collapsing the focused tile moves focus to the most recently focused visible
  window, or to the desktop when none remains.
- A stack collapses as one region. Its spine represents the stack and restoring
  it preserves the members and active member.
- Neighboring spines retain layout order and use a consistent narrow thickness.
  Exact dimensions and styling are deferred.
- Attention is shown on a collapsed window's spine without restoring it,
  focusing it, or switching Workspaces. A stack and its spine identify which
  inactive member requests attention without selecting that member.
- A manually collapsed region remains collapsed until the user restores it.

When a display cannot satisfy the saved layout's minimum sizes, ShapeBit may
temporarily auto-collapse eligible regions from least to most recently focused.
The focused window and a window with an active modal dialog are never eligible.
This does not change the saved layout.

Automatically collapsed regions restore when space becomes available. If the
user activates one while space remains constrained, it expands and the next
eligible least-recently-focused region collapses. An explicit restoration of a
manually collapsed region has the same priority.

## Stacks

- A user-initiated window added to a stack becomes its active, visible member.
  An unsolicited background window remains inactive and requests attention.
- When the visible member closes, the most recently used remaining member
  becomes visible. It receives focus only when focus was already in the stack.
  Closing an inactive member changes neither the visible member nor focus.
- Members have a stable, user-reorderable sequence. Next and previous
  navigation follows that sequence rather than recent-use order.
- Moving a member out of a stack creates a normal tile at the chosen insertion
  point and leaves the remaining stack in place.
- A separate **Move stack to Workspace** action transfers the whole stack as one
  tiled region while preserving its member order and active member.

## Floating windows

- A transient dialog floats centered over its parent, remains in the same
  Workspace, and moves with the parent.
- A modal blocks only its parent window or parent stack unless the application
  creates a valid application-wide modal.
- Floating windows appear above tiled windows and below system UI. The focused
  floating window is raised above other floating windows.
- An explicitly floated window persists its size and position in the Workspace
  layout. Temporary dialogs do not create persistent layout entries.
- A parentless floating window opens on the display containing the focused
  window, or the pointer when no window is focused. It is centered in the
  usable area, with a small cascading offset when that position is occupied.
- A resizable window that does not fit is reduced to the usable area. A
  fixed-size window may extend beyond the display, but its title bar and window
  controls remain reachable.
- Users may place a floating window partly off-screen while a portion containing
  its title bar or move control remains reachable.
- Returning a floating window to tiled placement restores its previous tiled
  position when that position still exists; otherwise, normal insertion applies.
- Making a tiled window floating restores its last floating geometry when
  available. Otherwise, ShapeBit derives a size from the current tile and
  centers it on the same display.

## Expanded and fullscreen presentation

- Tiled, stacked, and floating windows support expanded and fullscreen
  presentation without changing their underlying placement. Restoring normal
  presentation returns the previous tile, stack, or floating geometry.
- Presentation belongs to each window. A window retains expanded or fullscreen
  state while inactive and returns in that state when revisited.
- Focusing a different window on the same display shows that window above an
  inactive expanded or fullscreen window. Moving focus to another display
  leaves the presented window visible on its own display.
- Each stack member retains its own presentation. Switching from a fullscreen
  member to a normal member returns the stack to its tiled region; returning to
  the first member restores fullscreen.
- A dialog appears above its fullscreen parent while the parent remains
  fullscreen behind it.
- Expanded and fullscreen presentation affect only the window's current
  display. Other displays remain usable.
- For a floating window spanning displays, the current display is the one that
  contains the largest portion of the window.
- Fullscreen hides desktop chrome only on its display. Chrome remains visible
  on every other display.
