# Shelf

The Shelf is a temporary, user-controlled place for keeping material close at
hand while working across [Workspaces](desktop-workspaces.md). This document records
intended behavior, not implemented or verified desktop behavior.

## Scope and contents

- The Shelf is global to the user, not owned by a Workspace, and cleared at
  logout.
- Items enter only through an explicit action such as dragging or **Send to
  Shelf**. Clipboard contents are never captured automatically.
- Files and folders remain references; the Shelf neither copies nor moves them.
  If a source disappears, its item is removed silently.
- Text, images, and URLs are temporary Shelf-owned snapshots.
- Removing an item never modifies or removes source data.

## Presentation and capacity

- The Shelf has no system-bar icon initially.
- The Shelf uses the bottom edge by default. A power-user setting can move it to
  the top, left, or right edge independently of system-bar placement. This is
  one per-user setting applied consistently to every display.
- Activating the configured edge reveals a compact preview bar. It remains
  visible until the user clicks outside or presses Escape; it does not close on
  a timer. Clicking the preview or dragging inward opens the full Shelf.
- For pointer input, only the display's outermost pixel boundary has activation
  priority over controls on the same edge; those controls remain clickable
  immediately inside it. Touch uses an inward edge swipe, and a keyboard
  shortcut provides the non-pointer equivalent.
- Holding compatible dragged material at the configured edge reveals the
  preview without dropping the material. When the Shelf uses a left or right
  edge, a window drag performs Workspace transfer instead and never opens the
  Shelf.
- Dropping new material on the preview inserts it at the beginning. Continuing
  to hold and dragging inward expands the full Shelf so the user can choose an
  exact insertion position.
- The keyboard shortcut cycles through **closed**, **preview**, **full Shelf**,
  and back to **closed**. On opening the preview, its first item receives
  focus; navigation follows the preview's axis, Enter expands the full Shelf on
  the focused item, and Escape closes the preview.
- The preview shows the first items in the Shelf's current order as small
  thumbnails or icons, followed by `+N` when more items exist. Clicking an item
  opens the full Shelf with that item selected rather than opening or copying
  it. Items can be dragged directly from the preview.
- The preview is thicker than the compact system bar. When both occupy the same
  edge, the preview replaces the bar immediately and extends inward over
  windows without changing their layout. Closing the preview restores the bar.
  A system bar on another edge remains visible.
- The full Shelf spans its configured edge on the current display and opens
  inward as an overlay. Its inner edge is draggable, and its size is remembered
  per user separately for each edge; default and limiting dimensions remain
  deferred.
- New items are inserted at the beginning of the Shelf. Users can reorder items
  by dragging them or through keyboard-accessible move-left/right commands. The
  custom order and contents persist together until logout, and the preview
  follows that order.
- The full Shelf uses a responsive grid. On a horizontal edge it flows
  left-to-right into rows and scrolls vertically; on a vertical edge it flows
  top-to-bottom into columns and scrolls horizontally.
- Arrow keys navigate the grid spatially; Home and End move to the first and
  last item. A single click selects an item. Enter or double-click activates it
  through its default handler: files, folders, and URLs open normally, while
  text and image snapshots open in a viewer.
- Opening, copying, using, or dragging an item out leaves it in the Shelf. Only
  an explicit removal action changes Shelf contents.
- An open Shelf continues to replace a system bar on the same edge. A bar on
  another edge remains visible.
- Shelf contents are global and only one overlay can be open at a time. Opening
  it on another display closes the previous overlay and reopens the same Shelf
  on the newly activated display. It appears only on that display, never across
  every display at once.
- Clicking outside or pressing Escape closes the overlay.
- The open Shelf overlays windows and never resizes or changes the tiled layout.
- A foreground fullscreen window disables configured-edge Shelf activation on that
  display. The explicit Shelf keyboard shortcut remains available and opens the
  overlay above fullscreen.
- The open Shelf remains open across Workspace switches.
- Opening Overview closes the Shelf overlay without changing its contents.
- Shelf and assistant chat remain independent surfaces and may be open together
  so items can be dragged into a conversation. With the default bottom Shelf on
  the same display, chat floats above its left side rather than becoming part of
  the Shelf. Coexistence with a power-user edge remains to be refined.
- There is no item-count limit; the overlay scrolls when full.
- Snapshots share a configurable storage-size limit. Existing items are never
  evicted silently.
- If a new snapshot exceeds that limit, the Shelf rejects it, explains why,
  and links to Shelf settings. File and folder references remain addable.

## Removal

- Individual removal is immediate and confirmation-free, with a brief
  **Undo** action.
- Hovered or keyboard-focused items expose **Remove**; Delete removes the
  selected item.
- **Clear Shelf** removes every item immediately without confirmation and
  provides a brief **Undo** action.
