# Shelf

**Status:** Draft

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
- The Shelf is a bottom-edge surface independent of system-bar placement. It
  does not move when the user moves the system bar to the top.
- Clicking or tapping the bottom edge reveals a small Shelf bar. The Shelf opens
  upward from that bar as an overlay.
- When the system bar is at the bottom, an open Shelf temporarily replaces it.
  When the system bar is at the top, it remains visible while the Shelf is open.
- Shelf contents are global and only one overlay can be open at a time. Opening
  it on another display closes the previous overlay and reopens the same Shelf
  on the newly activated display. Exact multi-display bottom-edge activation
  remains undecided.
- Clicking outside or pressing Escape closes the overlay.
- The open Shelf overlays windows and never resizes or changes the tiled layout.
- A foreground fullscreen window disables bottom-edge Shelf activation on that
  display. The explicit Shelf keyboard shortcut remains available and opens the
  overlay above fullscreen.
- The open Shelf remains open across Workspace switches.
- Opening Overview closes the Shelf overlay without changing its contents.
- Shelf and assistant chat remain independent surfaces and may be open together
  so items can be dragged into a conversation. Their exact coexistence layout
  remains undecided.
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
