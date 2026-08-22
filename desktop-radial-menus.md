# Radial Context Menus

ShapeBit-owned context menus use a radial, or pie, presentation instead of a
traditional vertical list. This document records intended behavior, not
implemented or verified desktop behavior.

## Scope and ownership

- Radial context menus are required across the ShapeBit shell and first-party
  graphical applications.
- The shell owns menus for Workspaces, window chrome, the system bar, Overview,
  Shelf, notifications, and other shell surfaces.
- First-party applications use a shared ShapeBit radial-menu component while
  retaining ownership of their contextual actions.
- Third-party Wayland applications retain context menus rendered inside their
  own surfaces. ShapeBit does not intercept or replace them.
- Third-party applications and extensions cannot inject, remove, or reorder
  actions in shell-owned menus until ShapeBit defines a trusted extension
  model.

The object owner captures the context target when the menu opens and validates
that target again before executing an action. A stale menu cannot act on an
object that was removed or changed into an incompatible state.

## Activation and execution

- The menu appears when the configured secondary pointer button is pressed.
  Releasing without leaving the neutral center keeps it open for inspection.
- Moving into a wedge while holding the secondary button and then releasing
  executes the highlighted action immediately.
- Moving outside the neutral center highlights a wedge but does not execute it.
  Returning to the center cancels the current selection.
- Releasing over an enabled action executes it and closes the menu. Releasing
  in the center or between wedges closes the menu without action.
- Releasing over a disabled action keeps the menu open and explains why the
  action is unavailable.
- In inspection mode, an action executes only after an explicit primary click
  on its wedge.
- Escape, a primary click outside the menu, or activating **Cancel** in the
  root center closes the menu without action.
- An ordinary successful action closes the menu. An action that requires
  further input closes it before opening the next appropriate surface.
- A destructive, privileged, or consent-requiring action opens the ordinary
  confirmation, trusted authorization, or portal flow. The radial menu never
  substitutes for those controls.

## Layout and stable positions

- One radial level contains at most eight wedges.
- Every wedge has a stable directional sector for the same object type. Menus
  do not reorder actions according to recent use or current availability.
- The primary action uses the top sector. Destructive actions use a declared,
  consistent lower sector and remain identifiable by both icon and styling.
- Temporarily unavailable actions remain visible but disabled so other actions
  do not move into their sectors.
- Context-specific optional actions may occupy declared empty sectors but may
  not move core actions.
- Common actions belong in the root ring. Related or less frequent actions may
  be grouped in a secondary radial level.

## Secondary levels

- A category wedge has a visible outward indicator.
- Clicking or releasing over a category replaces the current ring with its
  secondary level at the same center.
- During a held gesture, crossing the category wedge's outer boundary opens
  the secondary level without requiring release. The user may then continue in
  another direction and release to execute an action.
- Only one ring is visible at a time. The center of a secondary level shows the
  category name and **Back**.
- Moving into the center, activating **Back**, or pressing Backspace returns to
  the parent level. Escape closes the complete menu.
- Opening a secondary level never depends on a hover delay.
- A menu may contain the root plus at most two secondary levels.

## Screen-edge placement

- The ring normally opens around the activation point.
- When it would cross a display edge, the complete ring shifts inward just
  enough to remain visible. Its sectors do not rotate or reorder.
- A subtle connector identifies the captured object or original activation
  point when the ring moves.
- The pointer is never warped. After an edge adjustment, pointer motion is
  ignored until it enters the shifted center's neutral zone, preventing the
  initial offset from selecting an action accidentally.
- Normal directional selection begins after the pointer enters that zone. This
  may require one additional movement for an invocation very close to an edge.

## Keyboard, touch, pen, and accessibility

- Touch and pen open the menu through long-press. Continuing to hold, moving
  into a wedge, and releasing follows the same gesture-selection rules.
- The keyboard Menu key opens it around the focused object. ShapeBit also
  exposes an **Open context menu** action that users may assign to another
  shortcut when their keyboard has no Menu key. `Shift+F10` is not assigned.
- Arrow keys select the nearest wedge in their direction. Enter or Space
  activates it, Backspace returns from a secondary level, and Escape closes the
  complete menu.
- Holding a direction changes selection but never repeatedly executes an
  action.
- No action depends only on color, animation, precise pointer movement, or
  gesture speed. The menu has no timeout.
- Every wedge always shows an upright icon and short text label. Screen readers
  announce the captured target, selected action, disabled state, and whether an
  action opens a secondary level.
- The menu supports text scaling, high contrast, and reduced motion. Touch or
  pen selection may provide subtle haptic feedback when hardware supports it;
  selection has no sound by default.

## Visual feedback

- The center identifies the captured target or current category and provides
  the applicable **Cancel** or **Back** action.
- The selected wedge receives a clear outline and slight expansion.
- Destructive actions use both a warning icon and warning color. Disabled
  actions remain readable with reduced emphasis.
- Opening and level changes use a short fade and scale transition. Reduced
  motion removes movement and uses an immediate fade.
- Exact radius, typography, spacing, target dimensions, colors, and animation
  duration belong to the ShapeBit visual-system specification.
