# Desktop Environment

The OS is based on Hyprland and Quickshell.

## Window Management

ShapeBit Desktop uses tiling by default while retaining explicit stacking and
floating placement. Placement, presentation, and keyboard focus are separate
properties. This document records intended behavior, not implemented or
verified desktop behavior.

### Tiling insertion and removal

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

### Collapsed tiles and constrained space

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

### Stacks

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

### Floating windows

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

### Expanded and fullscreen presentation

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
- Fullscreen hides desktop chrome only while it is the foreground presentation
  on its display. Chrome returns when a non-fullscreen window comes to the
  foreground there and remains visible on every other display.

## Radial Context Menus

ShapeBit-owned context menus use a radial, or pie, presentation instead of a
traditional vertical list. This document records intended behavior, not
implemented or verified desktop behavior.

### Scope and ownership

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

### Activation and execution

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

### Layout and stable positions

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

### Secondary levels

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

### Screen-edge placement

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

### Keyboard, touch, pen, and accessibility

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

### Visual feedback

- The center identifies the captured target or current category and provides
  the applicable **Cancel** or **Back** action.
- The selected wedge receives a clear outline and slight expansion.
- Destructive actions use both a warning icon and warning color. Disabled
  actions remain readable with reduced emphasis.
- Opening and level changes use a short fade and scale transition. Reduced
  motion removes movement and uses an immediate fade.
- Exact radius, typography, spacing, target dimensions, colors, and animation
  duration belong to the ShapeBit visual-system specification.

## Shelf

The Shelf is a temporary, user-controlled place for keeping material close at
hand while working across Workspaces. This document records
intended behavior, not implemented or verified desktop behavior.

### Scope and contents

- The Shelf is global to the user, not owned by a Workspace, and cleared at
  logout.
- Items enter only through an explicit action such as dragging or **Send to
  Shelf**. Clipboard contents are never captured automatically.
- Files and folders remain references; the Shelf neither copies nor moves them.
  If a source disappears, its item is removed silently.
- Text, images, and URLs are temporary Shelf-owned snapshots.
- Removing an item never modifies or removes source data.

### Presentation and capacity

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

### Removal

- Individual removal is immediate and confirmation-free, with a brief
  **Undo** action.
- Hovered or keyboard-focused items expose **Remove**; Delete removes the
  selected item.
- **Clear Shelf** removes every item immediately without confirmation and
  provides a brief **Undo** action.

## Notifications

ShapeBit notifications provide visible but non-focus-stealing attention across
Workspaces. This document records intended behavior,
not implemented or verified desktop behavior. Privacy, lock-screen, sharing,
critical-notification, and Do Not Disturb constraints remain owned by
[Media, Privacy, and Notification Policy](desktop.md).

### Notification panel

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

### Workspace routing

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

### Banners

- Banners appear beside the notification indicator: upward from a bottom bar
  or downward from a top bar. With the bar hidden by fullscreen, they use the
  same configured corner where the indicator normally appears.
- At most three ordinary banners are visible at once. Additional notifications
  go directly to the center until space becomes available.
- Ordinary banners close after a configurable short duration. Hover or keyboard
  focus pauses the timer, and the notification remains in the center afterward.
- Verified critical system notifications remain visible until explicitly
  handled or dismissed.

### Dismissal and policy

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

## Quick Settings

Quick Settings provides fast access to selected system controls without
replacing the complete Settings application. This document records intended
behavior, not implemented or verified desktop behavior.

### Panel placement

- Quick Settings is one global panel. Clicking a system-bar status cluster
  opens the panel on that cluster's display; the keyboard shortcut uses the
  focused window's display. Only one instance is visible at a time.
- Clicking outside, pressing Escape, or clicking the originating status cluster
  again closes the panel without changing settings by itself. Applied changes
  remain in effect; unsaved form edits are discarded.

### Interaction model

- The panel always opens as one overview rather than jumping to a section based
  on the status icon used to open it.
- The overview visibly groups controls in the fixed order **Connectivity**,
  **Privacy**, **Sound & Display**, and **Power**. Each group has a small visible
  text heading in addition to spacing and visual separation. User reordering is
  deferred to a future version and will be configured through the full Settings
  application. The initial panel has no search, pinning, custom tiles, or local
  reordering.
- The panel is bounded by the available display height. When its groups do not
  fit, they scroll inside the panel while the Settings button remains fixed and
  visible.
- Controls always reflect actual system state and update live when hardware,
  another application, or another session changes that state.
- Tab and Shift+Tab move between controls. Arrow keys operate sliders and
  choices within the focused control; Enter or Space activates it.
- Keyboard focus remains inside the open panel. Closing it returns focus to the
  system-bar control or window that opened it. Every icon, state, progress
  indicator, and error has an accessible text label; important distinctions do
  not depend on color alone. The panel respects text scaling, high contrast,
  reduced motion, and screen-reader output.
- Switches, sliders, and device choices apply immediately. A view containing
  editable values uses an explicit **Save**, **Start**, or equivalent action;
  closing the view or panel discards its unsaved edits. Leaving a detail view or
  closing the panel hides revealed secrets and QR codes, which must be revealed
  explicitly again.
- If a setting change fails, its control returns to the actual system state and
  shows an inline explanation without closing the panel. The error remains
  until a later attempt succeeds or the panel closes; it has no separate
  dismiss control.
- While a setting change is in progress, its control shows a progress state and
  prevents repeated activation until the operation completes. Closing the panel
  does not cancel the operation; reopening it shows the operation's current or
  final actual state. If it fails while the panel is closed, ShapeBit delivers
  a normal failure [notification](#notifications). Successful
  completion while the panel is closed remains silent and is reflected only in
  the resulting system status.
- Binary settings use switch tiles. The initial examples include Wi-Fi and
  Bluetooth. Airplane Mode is also an initial switch tile on devices with
  supported wireless hardware. Airplane Mode controls wireless radios rather
  than all networking: it disables Wi-Fi and Bluetooth and stops an active
  hotspot, while Ethernet remains usable. VPN follows the remaining transport
  and its normal reconnect and kill-switch rules. Turning Airplane Mode off
  restores each radio to its individual state from before it was enabled but
  does not restart the hotspot. Individual radios cannot be re-enabled while
  Airplane Mode remains active.
- When wired networking is present, **Connectivity** shows a read-only Ethernet
  status row with connection state and the network name when known. Detailed
  wired configuration remains in the full Settings application.
- The Wi-Fi detail view lists visible networks and supports connecting or
  disconnecting without leaving Quick Settings. A simple network password is
  entered inside the same detail view. Certificate-based or otherwise advanced
  setup closes the panel and opens the relevant page in the full Settings
  application. The connected network appears first, followed by saved networks
  and then other available networks ordered by signal strength. Each row shows
  connection state, signal strength, and whether the network is secured, but
  does not claim an estimated internet speed. Quick Settings does not provide a
  **Forget** action; saved-network management remains in the full Settings
  application.
- The Bluetooth detail view shows connected devices first, then paired devices,
  then newly discovered devices. Pairing and connect or disconnect actions stay
  inside the panel. PIN or passkey entry and comparison also remain in the
  detail view. A pairing failure shows an inline error and leaves the panel
  open. New-device discovery runs while the detail view is open; connected and
  paired devices remain visible without continuous aggressive scanning. A
  device battery level appears only when the device reports it reliably. Quick
  Settings does not provide an unpair action; removing a paired device remains
  in the full Settings application.
- A Mobile Hotspot tile appears only when the Wi-Fi hardware supports hotspot
  mode. On first use, it opens a detail view with a neutral generated network
  name and a secure random password; broadcasting begins only after the user
  activates **Start**. The detail view continues to show and allow editing of
  the saved hotspot name and password after initial setup. The password is
  masked by default and has explicit reveal and **Copy** controls; copying does
  not reveal it onscreen. The detail view also provides a QR code that another
  device can scan to join, but the code remains hidden until the user activates
  **Show QR code**. Saving a changed name or password while the hotspot is active
  requires confirmation that connected devices will be disconnected. After
  confirmation, the hotspot restarts automatically with the new credentials.
  Later uses may toggle the saved hotspot directly. While it is active, the
  detail view lists the devices currently connected to it and provides a
  **Disconnect** action for each device. Each device shows its reported name
  when available, otherwise its IP and MAC addresses. Disconnecting is temporary
  and does not prevent that device from reconnecting with the password; device
  blocking is available only in the full Settings application. An active
  hotspot's overview tile shows its number of connected devices. The hotspot
  continues while the session is locked but stops automatically at logout or
  restart.
- A VPN tile appears only after at least one VPN is configured. Its switch
  connects or disconnects the most recently selected VPN; its detail view
  selects another configured VPN. When connected, the overview tile shows the
  active profile's name. If that profile has its kill switch enabled, the tile
  also shows a read-only **Kill switch** badge; changing that profile option
  remains in the full Settings application. If its tunnel becomes unavailable
  while the kill switch blocks traffic, the tile prominently shows
  **Reconnecting — network blocked**. A reconnecting profile without a kill
  switch instead shows **Reconnecting — traffic not protected**. The compact
  system-bar VPN indicator also visually distinguishes connected,
  reconnecting-with-traffic-blocked, and reconnecting-without-protection states;
  hovering it shows the active profile name and exact connection and protection
  state. The initial release allows only one active VPN profile at a time;
  selecting another disconnects the current VPN before connecting the new one.
  If the new connection fails, ShapeBit automatically attempts to reconnect the
  previously active VPN. If restoration also fails, the error reports both
  failures and states explicitly that no VPN is active.
  Switching otherwise starts immediately without an additional confirmation;
  the confirmation and authorization requirements in
  [Network Ownership and Privacy](security-identity.md) still apply. Supported
  VPN types and system-wide routing remain governed by
  [Enterprise Network Authentication](security-identity.md) and the
  [architecture index](architecture.md).
- Cellular, NFC, and other additional radio controls are deferred until their
  hardware and policy models are designed. Quick Settings does not claim a
  dedicated captive-portal workflow; that remains outside the initial release
  under [Network Ownership and Privacy](security-identity.md).
- A Camera switch tile exposes the global camera-disable control defined by
  [Media, Privacy, and Notification Policy](desktop.md) and applies to all
  applications subject to that decision's documented enforcement boundaries.
  Its direct meaning is **On = camera available** and **Off = camera globally
  blocked**. If a controlled client retains an active camera session while
  access is disabled, the unhideable privacy indicator remains visible, names
  the client, and shows that the camera is blocked.
- Hardware microphone-mute and camera-shutter states take precedence over the
  software controls. When hardware blocks access, the corresponding software
  control is unavailable and labeled **Blocked by hardware**. Per-application
  microphone and camera permission management remains in the full Settings
  application.
- **Privacy activity** lists ongoing microphone, camera, screen-sharing, and
  remote-control activity. Entries are ordered by sensitivity: remote control,
  screen sharing, camera, then microphone, with the newest activity first within
  each type. Each entry shows the application, the accessed resource or shared
  scope, and how long the activity has been active. An entry exposes **Stop**
  whenever the controlled capture or remote-control boundary supports immediate
  revocation, consistent with [Media, Privacy, and Notification Policy](desktop.md). Stop acts immediately without
  confirmation, revokes only the selected activity, and does not change the
  global Camera or microphone-mute controls. Stopping remote control leaves its
  associated screen-sharing session active. Stopping screen sharing also
  revokes any remote-control session attached to it.
  Attached remote-control and screen-sharing activity remains in separate
  entries, but the panel visually links those entries. When no Privacy activity
  is ongoing, its list is hidden while the normal Privacy controls remain
  visible. Ended activity disappears from Quick Settings immediately; the panel
  does not include recent history, and the desktop does not retain a Privacy
  activity history elsewhere. Unhideable privacy indicators remain visible
  above Quick Settings itself and are never suppressed by opening the panel.
- Continuous settings such as output volume and display brightness use sliders.
  The overview volume slider names and controls the current default audio
  output. Hardware volume keys and external state changes update it live. Its
  detail view selects another output device and lists active applications with
  current audio streams, each with independent volume and mute controls. An
  application leaves the list when its streams end, while its settings remain
  remembered for the next stream. Clicking the speaker icon toggles mute;
  unmuting restores the previous volume. Normal volume is limited to 100%; the
  panel does not offer software amplification.
  The overview also exposes microphone input volume and input-device selection
  rather than placing them only in the audio detail view. Clicking the
  microphone icon toggles input mute; unmuting restores the previous input
  level. Its direct meaning is **On = input available** and **Muted = input
  globally blocked**. This is the global microphone mute defined by
  [Media, Privacy, and Notification Policy](desktop.md): it affects
  applications and local-assistant voice input, subject to that decision's
  documented enforcement boundaries. If a controlled client retains an active
  microphone session while global mute blocks input, the unhideable privacy
  indicator remains visible, names the client, and shows that input is muted.
  The overview brightness slider controls the display containing the panel. Its
  detail view provides separate controls for other displays whose brightness
  can be controlled reliably. Layout, scale, orientation, primary-display
  choice, and color calibration remain in the full Settings application.
- A Night Light switch tile appears in **Sound & Display**. Its detail view
  controls color temperature and scheduling. Night Light is disabled by
  default. First activation turns it on immediately without creating a
  schedule; scheduling remains optional. When a schedule exists, a manual
  switch change overrides it only until the next scheduled transition.
- An HDR switch tile appears only when the display containing the panel supports
  HDR and controls that display only. Its detail view provides separate controls
  for other supported displays. While HDR is active, the detail view provides
  separate sliders for physical display brightness and the reference brightness
  of SDR content. HDR state and safe SDR fallback remain defined by
  [Display, Power, and Thermal Policy](desktop.md).
- A VRR control appears only when the display containing the panel supports
  variable refresh rate. It shows **Automatic for fullscreen** by default and
  allows VRR to be disabled for that display, consistent with [Display, Power, and Thermal Policy](desktop.md).
- If the current display pipeline cannot safely combine HDR, VRR, Night Light,
  or another selected mode, Quick Settings preserves the working configuration,
  disables the conflicting control, and explains why rather than silently
  degrading display state. Keyboard-backlight and automatic-brightness controls
  are deferred until ShapeBit defines their hardware-policy model.
- When a setting has additional choices, its tile label or a separate details
  affordance opens a focused detail view inside the same panel without changing
  the setting. A Back control returns to the overview. The switch itself changes
  the setting immediately. Returning from the detail view restores keyboard
  focus to the control that opened it.
- In a detail view, Escape returns to the overview. Pressing Escape again closes
  the panel.
- A persistent **Settings** button closes Quick Settings and opens the full
  Settings application. If a Settings window already exists, ShapeBit switches
  to its Workspace and focuses it without moving it. Otherwise, Settings opens
  in the active Workspace on the display where the panel was shown.
- A control for hardware the device does not support is hidden. A supported
  control that is temporarily unavailable remains visible but disabled and
  explains the blocking condition.
- On battery-powered devices, the overview shows battery percentage, charging
  state, and a remaining-time estimate only when the system considers that
  estimate reliable for the main system battery. Peripheral batteries remain
  with their owning device controls, such as a headset battery under Bluetooth,
  and are not combined with the system estimate. The overview also shows a
  power-profile selector. The available profiles are **Balanced**, **Power
  Saver**, and **Performance** when the platform supports it, as defined by
  [Display, Power, and Thermal Policy](desktop.md). When low battery
  automatically activates Power Saver, the selector labels it **Power Saver —
  Automatic** and temporarily disables the other profiles. Connecting external
  power restores the previously selected profile. When thermal policy limits
  performance, the panel shows **Performance limited by temperature**; thermal
  protection remains informational and cannot be disabled. Battery conservation
  and charging-limit controls remain in the full Settings application because
  they are system-wide and may require administrator confirmation under
  [Display, Power, and Thermal Policy](desktop.md).
- Power actions are presented as commands rather than switches. The Power
  control opens a focused view inside the panel and never performs a command
  immediately. Its initial commands are **Lock**, **Suspend**, **Log Out**,
  **Restart**, and **Shut Down**. Lock and Suspend act immediately. Log Out,
  Restart, and Shut Down require explicit confirmation. The confirmation names
  known blocking applications and, when the command affects them, other active
  local and SSH sessions. It also warns that ShapeBit cannot reliably detect or
  preserve every piece of unsaved work. **Cancel** receives initial focus in
  these destructive confirmations. When an update is staged, the relevant
  command may be labeled **Restart and Update**, while confirmation, recovery,
  and failure behavior remain governed by
  [Staged-Restart UX](system-lifecycle.md).

### System-bar status cluster

- The compact status cluster prioritizes exceptional states such as offline
  connectivity, a reconnecting VPN without protection, network traffic blocked
  by a kill switch, global microphone mute, global camera blocking, and low
  battery rather than permanently displaying every enabled feature.
- Hover text provides the exact state and relevant device or profile name.
  Critical distinctions use different icons or badges as well as color.

### Initial scope exclusions

- **Do Not Disturb** remains exclusively in the
  [Notification panel](#notifications) and is not duplicated in Quick
  Settings.
- Accessibility shortcuts, appearance and theme selection, keyboard layout,
  location services, and similar controls remain in the full Settings
  application initially. If later promoted, they use the planned configurable
  tile system rather than expanding the fixed initial panel.

## Assistant Framework

The assistant framework is the common local foundation for assistant and agent
interaction across ShapeBit Desktop. This document records intended behavior,
not implemented or verified desktop behavior.

### Scope

- Voice and chat are channels to the same framework, not separate assistants.
  The framework and its agents run locally.
- The initial product has one global assistant agent shared across all Workspaces
  and both channels.
- Context access, capabilities, privileges, and confirmations do not vary by
  input channel.
- The global agent has one serialized request queue shared by voice Assistant
  mode and chat. Requests retain their source channel and run in arrival order.
- Cancelling the current request stops that operation and then allows the next
  queued request to begin. Cancellation does not silently discard the queue.
- Cancellation stops generation and requests cancellation from an active action
  only when that action supports it. It never rolls back completed effects and
  clearly reports when an in-progress action cannot be interrupted.
- A non-interruptible action continues to hold the serialized queue until it
  finishes; later requests never run concurrently through the same agent.
- The assistant system-bar control shows current activity and the number of
  queued requests, including while chat is hidden.
- Locking the session hides all assistant output. Already-authorized local work
  may continue, but results are exposed only after unlock. Requests that have
  not started remain paused in the queue until the session unlocks.
- Work that reaches a permission or confirmation step while locked pauses and
  presents the card only after unlock.

### Permissions and actions

- The assistant can access the current user's files, window contents, and
  clipboard without explicit per-item sharing. These read capabilities are
  granted by default to the initial agent.
- Access remains subject to the user's OS permissions and the framework's
  capability model; local execution bypasses neither.
- Permissions are assigned per agent and per capability, even while only one
  agent exists. One central permissions surface supports review and revocation.
- Write and control capabilities are disabled by default. ShapeBit requests a
  capability on first use, and an approved grant persists until revoked.
- Agents request typed actions through controlled APIs and cannot execute
  arbitrary shell commands.
- Reversible, non-destructive actions may run immediately. Destructive,
  privileged, or externally communicating actions require confirmation every
  time, regardless of persistent capability grants.
- Capability grants and required action confirmations must be activated through
  the visible card with pointer or keyboard input. Spoken confirmation is not
  sufficient in the initial design.

### History and memory

- The central assistant surface keeps a local activity log of requested and
  completed actions, confirmations, and permission changes.
- Log retention is user-configurable, and **Clear history** removes it
  immediately. Discarded voice audio and transcripts are never included.
- Assistant memory persists locally across voice and chat sessions. Users can
  view, edit, and clear it.
- Derived memories may survive a voice interaction, but raw audio and
  transcripts do not.

### Architecture constraint

The confirmed window-content goal does not yet distinguish semantic data
exposed by an application from captured screen pixels. Accepted
[Media, Privacy, and Notification Policy](desktop.md)
requires a new portal selection for each screen-image capture and does not
retain that permission. Unrestricted pixel access is therefore not authorized
unless a later decision supersedes [Media, Privacy, and Notification Policy](desktop.md).

### Open decisions

Detailed capability scopes, the semantic-data versus screen-pixel boundary,
memory selection, and future agent isolation remain undecided. Cross-system
authorization constraints remain owned by the ShapeBit OS architecture and
architecture sections.

## Assistant Chat

Assistant chat is a text interface to the shared local
[assistant framework](#assistant-framework). This document records
intended behavior, not implemented or verified desktop behavior.

### Surface

- Chat is a global, on-demand overlay not owned by a Workspace.
- Chat is an independent, frameless overlay anchored at the bottom-left. It is
  not a pane or region inside the Shelf and does not use per-conversation
  chat-head icons.
- It opens from the system bar or a user-configurable shortcut and remains
  hidden when inactive.
- A bar button opens chat on that button's display; the shortcut uses the
  focused window's display. Only one global chat panel is open at a time.
- Clicking outside focused chat reduces it to the passive three-bubble state;
  clicking outside again while passive hides it. Escape or the close control
  hides it immediately. Hiding chat never ends the conversation or stops
  ongoing work; reopening restores the same conversation and position.
- The overlay is resizable from its top and right bounds, and its size is
  remembered per user. Most of its bounding area remains visually transparent.
- Opening chat alone does not hide the system bar. With a bottom bar, chat sits
  immediately above it; with a top bar, chat sits at the bottom-left edge.
- Chat and Shelf may remain open together. With the default bottom Shelf on the
  same display, chat moves above the Shelf preview immediately and farther
  upward when the full Shelf opens, then returns as those surfaces close.
  Moving the Shelf to another display does not move an already-open chat panel.
  Coexistence with a power-user Shelf edge remains to be refined.

### Bubble presentation

- Recent messages appear as floating bubbles above a compact input. Older
  messages remain available by scrolling within the overlay bounds.
- A small conversation header and the input appear when the overlay is hovered
  or receives keyboard focus. The header exposes the current title,
  conversation list, new-conversation action, and close control.
- Without hover or keyboard focus, the input and header hide and only the three
  most recent bubbles remain visible. Hover or focus restores the full
  scrollable conversation surface.
- Clicking a passive bubble focuses chat, restores its input and header, and
  expands the full conversation around that message.
- The keyboard shortcut and assistant system-bar icon share toggle semantics:
  hidden chat opens with the input focused; passive chat receives focus; an
  already focused chat hides.
- Focused and passive chat remain open across Workspace switches on the same
  display.
- Overview temporarily hides chat and restores its previous focused or passive
  state when Overview closes.
- A foreground fullscreen window temporarily hides chat on its display and
  restores it when fullscreen leaves. The explicit chat shortcut may still open
  chat above fullscreen when intentionally requested.
- If chat is completely hidden, a new assistant response never makes it appear
  automatically. The assistant system-bar control shows completion or attention
  instead. If chat is already open in its passive bubble state, the new response
  may appear there.
- Assistant responses stream progressively into one bubble. While a response or
  action is active, the Send control becomes **Stop**. Escape hides chat without
  stopping the agent.
- The input remains usable during active work. Sending another message adds it
  to the visible shared assistant queue rather than interrupting the current
  operation; queued items identify whether they came from chat or voice.
- Switching conversations never moves or cancels work. Every queued request and
  result remains attached to its originating conversation while another
  conversation may be visible.

### Conversations

- Multiple conversations and their messages persist locally until deleted.
- Each conversation has its own history, while assistant memory remains global
  across conversations.
- New conversations receive locally generated titles that users can rename.
- The conversation list is ordered by latest activity and supports local search
  across titles and messages.
- Deletion is immediate and confirmation-free, with a brief **Undo** action.

### Actions and confirmations

- Assistant tool and action requests appear as structured cards between message
  bubbles. Cards show pending, running, completed, or failed state rather than
  representing execution as ordinary assistant prose.
- A capability permission request and an individual action confirmation are
  separate cards. Granting a capability never also approves a destructive,
  privileged, or externally communicating action waiting behind it.
- When confirmation is required while chat is passive, the pending card remains
  visible among the three passive items and the assistant system-bar control
  marks attention. Chat does not take focus automatically. If chat is hidden,
  only the bar attention state appears until the user opens it.
- A completed action card collapses to a compact result summary with expandable
  details. The complete event also remains in the central assistant activity
  log defined by the shared framework.

Chat uses the same global assistant, memory, capabilities, privileges, and
confirmation rules as voice Assistant mode, all defined by the shared
[assistant framework](#assistant-framework).

## Voice Interaction

Voice interaction lets the user work with ShapeBit through local AI agents.
This document records intended behavior, not implemented or verified desktop
behavior.

### Capture and privacy

- Voice interaction is push-to-talk only; there is no always-listening mode.
- Capture begins only after the explicit push-to-talk action and stops when the
  interaction ends.
- ShapeBit provides a default push-to-talk key or button that the user can
  reconfigure.
- The system bar shows a microphone indicator during capture. Clicking it
  immediately cancels the interaction.
- Speech recognition and agent processing run locally. Audio, transcripts, and
  agent requests are never sent to cloud services.
- Captured audio and transcripts are discarded after each interaction by
  default.
- All modes are unavailable on the login screen, lock screen, and
  authentication prompts.

Microphone access and privacy indication remain subject to
[Media, Privacy, and Notification Policy](desktop.md).

### Modes

- **Assistant:** Sends the utterance to a local agent as a request.
- **Speech to text:** Inserts a local transcription into the focused text
  input.
- **Speech to text with translation:** Translates the local transcription and
  inserts it into the focused text input. The current input language is the
  default translation target.
- The mode is explicitly selected, visibly indicated, and remembered per user;
  it is never inferred from speech. **Assistant** is the initial mode for a new
  user.

Assistant mode uses the shared
[assistant framework](#assistant-framework)
also used by chat interaction.

Ordinary Assistant responses are spoken through local text-to-speech by
default. A per-user setting may also show them temporarily as floating assistant
bubbles, but that presentation is disabled initially. Generated response text
is discarded after speech by default unless it contributes to a logged action
or derived memory.

While speech output is active, the system bar shows an indicator. Clicking it
stops speech immediately without undoing completed actions. Pressing
push-to-talk also stops current speech and begins a new capture immediately.
Other playing audio is ducked rather than paused during assistant speech and
restored afterward. This default is configurable per user.
When a voice Assistant request is queued behind existing work, ShapeBit plays a
short local acknowledgement sound and updates the assistant queue count instead
of speaking a full status message.
Locking the session stops assistant speech immediately. No assistant speech or
visual output appears on the lock screen; results from continuing authorized
work become available only after unlock.

If a voice Assistant request needs capability permission or action
confirmation, the assistant bubble overlay presents the same structured card as
chat even when ordinary response bubbles are disabled. This does not create a
persistent chat conversation or retain the voice transcript. The resulting
action event remains in the central assistant activity log.

### Deferred details

The exact default push-to-talk control will be selected later.

## Gaze Input

Gaze input is an optional way to position the pointer at the place where the
user is looking. This document records intended behavior, not implemented or
verified desktop behavior.

### Activation

- Gaze input is enabled by default for each user and can be disabled.
- Looking alone never moves the pointer or activates an interface element.
- An explicit keyboard key or mouse button moves the pointer to the latest
  stable gaze point without clicking. ShapeBit provides a default trigger that
  the user can reconfigure.
- With a reliable point, the trigger moves the pointer immediately and shows a
  brief visual ripple at the destination so it is easy to locate.
- The destination is the measured gaze point; ShapeBit does not snap to nearby
  controls by default.
- The trigger does nothing during an active pointer drag or resize, preventing
  an object from being moved unexpectedly.
- The system bar shows a privacy indicator whenever tracking is active. The
  indicator provides direct pause and resume controls.

### Data boundary

- Camera frames and derived gaze data remain local and transient. Only the
  latest stable gaze point is held in memory.
- Applications and agents cannot access frames, gaze data, or that point.
- Tracking stops on the login screen, lock screen, and authentication prompts,
  and resumes only in the unlocked user session.

Camera access and privacy indication remain subject to
[Media, Privacy, and Notification Policy](desktop.md).

### Calibration and reliability

- First login with supported hardware offers guided calibration. It may be
  skipped, but tracking remains paused until calibration succeeds.
- Without supported gaze hardware, the feature remains inactive without
  repeated prompts or error indicators. Settings shows that it is unavailable.
- If the trigger is pressed without a reliable point, the pointer remains in
  place and a brief recalibration notice appears.
- Sustained low confidence pauses tracking and offers recalibration instead of
  repeatedly showing notices.
- Calibration is stored separately for each display, and the pointer may move
  directly between calibrated displays. Looking at an uncalibrated display does
  not move the pointer and offers calibration instead.
- A display-position, orientation, scaling, or physical-setup change that makes
  stored calibration unreliable pauses tracking for that display until it is
  recalibrated.

### Deferred details

The exact default binding, stability and confidence thresholds, and detailed
recalibration flow will be selected later.
