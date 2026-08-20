# Shelf

**Status:** Draft

The Shelf is a temporary, user-controlled place for keeping material close at
hand while working across [Projects](desktop-goals.md). This document records
intended behavior, not implemented or verified desktop behavior.

## Scope and contents

- The Shelf is global to the user, not owned by a Project, and cleared at
  logout.
- Items enter only through an explicit action such as dragging or **Send to
  Shelf**. Clipboard contents are never captured automatically.
- Files and folders remain references; the Shelf neither copies nor moves them.
  If a source disappears, its item is removed silently.
- Text, images, and URLs are temporary Shelf-owned snapshots.
- Removing an item never modifies or removes source data.

## Presentation and capacity

- The Shelf is an on-demand overlay opened with a screen-edge gesture and
  hidden when inactive.
- The default edge is the right edge of the display and is user-configurable.
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
