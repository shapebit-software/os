# Desktop Environment

ShapeBit's desktop runs on **Hyprland** (the window manager and compositor)
and **Quickshell** (the shell that builds the bar, panels, menus, and
overlays). This document covers ShapeBit-specific design on top of that
foundation — not Hyprland's or Quickshell's own default behavior.

## Window Management

ShapeBit tiles by default but keeps explicit stacking and floating as first-class
options; placement, presentation, and keyboard focus are separate properties.
Hyprland already handles the core mechanics — inserting and splitting tiles,
floating windows, window groups (tabs), and fullscreen. This section covers
only what ShapeBit adds on top.

### Collapsing tiles into spines

- A tiled window can be manually collapsed into a narrow spine at its original
  position; neighbors temporarily take its space. Activating the spine
  restores the saved size and focuses the window.
- Collapsing the focused window moves focus to the most recently focused
  visible window, or to the desktop if none remain.
- A stack collapses as one spine; restoring it brings back every member and
  the previously active one.
- Spines stay in layout order and share one consistent thin size (exact
  dimensions and styling are deferred).
- A window can request attention on its spine without being restored,
  focused, or switching Workspaces. For a stack, the spine identifies which
  inactive member wants attention without selecting it.
- A manually collapsed window stays collapsed until the user restores it.

### Auto-collapse under constrained space

When a display can't fit the saved layout's minimum sizes, ShapeBit
temporarily auto-collapses eligible regions, least recently focused first.
The focused window and any window with an open modal are never eligible.
This never changes the saved layout.

- Auto-collapsed regions restore automatically once space allows.
- Activating one while space is still tight expands it and collapses the
  next least-recently-focused region instead. Restoring a manually collapsed
  region follows the same priority.

### Stacks

Hyprland's window groups already behave like tabs. ShapeBit adds:

- A window the user actively adds becomes the stack's visible, active
  member. An unsolicited background window stays inactive and requests
  attention instead.
- Closing the visible member reveals the most recently used remaining
  member; focus follows only if focus was already in the stack. Closing an
  inactive member changes neither.
- Members keep a stable, user-reorderable sequence — independent of recency
  — for Next/Previous navigation.
- Dragging a member out creates a normal tile at the drop point and leaves
  the rest of the stack in place.
- **Move stack to Workspace** moves the whole stack as one tiled region,
  keeping member order and the active member.

### Floating windows

- A transient dialog floats centered over its parent, stays in the parent's
  Workspace, and moves with it. A modal blocks only its parent window or
  stack, unless the app declares a valid app-wide modal.
- Floating windows sit above tiled windows and below system UI; the focused
  floating window rises above other floating windows.
- An explicitly floated window keeps its size and position in the Workspace
  layout; temporary dialogs don't create persistent layout entries.
- A parentless floating window opens centered on the display holding the
  focused window (or under the pointer if nothing is focused), with a small
  cascade offset if that spot is occupied.
- A resizable window that won't fit shrinks to the usable area; a
  fixed-size window may extend off-display, but its title bar and controls
  stay reachable. Users can likewise place a floating window partly
  off-screen as long as a portion with the title bar or move control stays
  reachable.
- Returning a floating window to tiled placement restores its previous
  tiled position if it still exists, otherwise normal insertion applies.
- Making a tiled window floating restores its last floating geometry if
  known; otherwise ShapeBit derives a size from the current tile and
  centers it on the same display.

### Expanded and fullscreen presentation

- Tiled, stacked, and floating windows can go expanded or fullscreen
  without losing their underlying placement; restoring returns the previous
  tile, stack, or floating geometry.
- Presentation belongs to each window and survives while it's inactive —
  the window returns in that state when revisited.
- Focusing another window on the same display shows it above an inactive
  fullscreen window; moving focus to another display leaves the fullscreen
  window visible there.
- Each stack member keeps its own presentation state. Switching from a
  fullscreen member to a normal one returns the stack to its tiled region;
  returning to the fullscreen member restores it.
- A dialog appears above its fullscreen parent, which stays fullscreen
  behind it.
- Expanded/fullscreen only affects the window's own display — other
  displays stay usable. For a floating window spanning displays, its
  "current" display is whichever contains the largest portion of it.
- Fullscreen hides desktop chrome only while it's the foreground
  presentation on its display. Chrome returns when a non-fullscreen window
  comes forward there, and stays visible on every other display.

## Radial Context Menus

ShapeBit-owned context menus use a radial ("pie") layout instead of a
traditional vertical list.

### Scope and ownership

- Required across the ShapeBit shell and first-party apps.
- The shell owns menus for Workspaces, window chrome, the system bar,
  Overview, Shelf, notifications, and other shell surfaces.
- First-party apps use a shared ShapeBit radial-menu component but own
  their own actions.
- Third-party Wayland apps keep their own in-surface context menus; ShapeBit
  doesn't intercept or replace them, and can't add, remove, or reorder their
  actions until ShapeBit defines a trusted extension model.
- The menu's owner captures its target object when it opens and re-validates
  that target before running an action, so a stale menu can't act on
  something since removed or changed into an incompatible state.

### Activation and execution

- Opens on the configured secondary pointer button. Releasing without
  leaving the center keeps it open for inspection.
- Moving into a wedge while holding the button, then releasing, runs that
  action immediately. Moving outside the center highlights a wedge without
  running it; returning to center cancels the selection.
- Releasing on an enabled action runs it and closes the menu; releasing on
  the center or between wedges closes it with no action. Releasing on a
  disabled action keeps the menu open and explains why it's unavailable.
- In inspection mode, an action runs only after an explicit click on its
  wedge.
- Escape, clicking outside, or **Cancel** in the center closes the menu
  without acting.
- A normal action closes the menu on success; one that needs more input
  closes the menu first, then opens the next surface.
- Destructive, privileged, or consent-requiring actions still go through
  the normal confirmation, authorization, or portal flow — the radial menu
  never replaces those.

### Layout and stable positions

- One level holds at most eight wedges. Each wedge has a fixed direction
  for a given object type — menus never reorder by recent use or
  availability.
- The primary action sits at the top; destructive actions sit in a
  consistent lower sector, marked by both icon and color.
- Temporarily unavailable actions stay visible but disabled, so others
  don't shift into their spot. Optional, context-specific actions can fill
  declared empty sectors but can't displace core actions.
- Common actions live in the root ring; related or less-frequent actions
  can move to a secondary level (at most two secondary levels per menu).

### Secondary levels

- A category wedge shows a visible outward indicator. Clicking it swaps the
  current ring for its secondary level at the same center.
- During a held gesture, crossing a category wedge's outer edge opens its
  secondary level without releasing — the user can continue into that level
  and release to act.
- Only one ring shows at a time; a secondary level's center shows the
  category name and **Back**. Moving to center, clicking **Back**, or
  pressing Backspace returns to the parent level. Escape closes the whole
  menu. Opening a secondary level never depends on a hover delay.

### Screen-edge placement

- The ring normally opens around the click point. If it would cross a
  display edge, the whole ring shifts inward just enough to stay visible —
  sectors don't rotate or reorder. A subtle connector marks the original
  activation point when the ring moves.
- The pointer is never warped. After an edge shift, pointer motion is
  ignored until it enters the shifted center's neutral zone, so the initial
  offset can't accidentally select something — this can mean one extra
  movement near an edge.

### Keyboard, touch, pen, and accessibility

- Touch and pen open the menu via long-press; holding, moving into a
  wedge, and releasing works the same as pointer gestures.
- The keyboard Menu key opens it around the focused object. ShapeBit also
  exposes an **Open context menu** action for keyboards without a Menu key.
  `Shift+F10` is not assigned.
- Arrow keys select the nearest wedge in that direction; Enter/Space
  activates it, Backspace goes back a level, Escape closes the menu.
  Holding a direction changes the selection but never repeats an action.
- No action depends only on color, animation, precise pointer movement, or
  gesture speed, and the menu never times out.
- Every wedge always shows an upright icon and short label. Screen readers
  announce the captured target, selected action, disabled state, and
  whether an action opens a secondary level.
- Supports text scaling, high contrast, and reduced motion. Touch/pen
  selection may give subtle haptic feedback if the hardware supports it;
  there's no sound by default.

### Visual feedback

- The center shows the captured target or current category, plus
  **Cancel** or **Back**. The selected wedge gets a clear outline and
  slight expansion.
- Destructive actions use both a warning icon and color; disabled actions
  stay readable but muted.
- Opening and level changes use a short fade-and-scale transition; reduced
  motion drops the movement for an immediate fade.
- Exact radius, typography, spacing, target size, colors, and animation
  timing belong to the ShapeBit visual-system spec, not this document.

## Shelf

The Shelf is a temporary, user-controlled place to keep material close at
hand while working across Workspaces.

### Scope and contents

- Global to the user, not owned by any Workspace, and cleared at logout.
- Items enter only through an explicit action (drag, **Send to Shelf**) —
  clipboard contents are never captured automatically.
- Files and folders stay as references; the Shelf doesn't copy or move
  them, and drops an item silently if its source disappears.
- Text, images, and URLs become Shelf-owned snapshots. Removing a Shelf
  item never touches the source data.

### Presentation and capacity

- No system-bar icon initially. Uses the bottom edge by default; a
  power-user setting can move it to top, left, or right, independent of the
  system bar — one setting, applied to every display.
- Activating the configured edge reveals a compact preview bar that stays
  open until the user clicks outside or presses Escape (no timeout).
  Clicking the preview or dragging inward opens the full Shelf.
- Only the display's outermost pixel has pointer-activation priority —
  other controls on that edge stay clickable right inside it. Touch uses an
  inward edge swipe; a keyboard shortcut covers non-pointer use.
- Holding compatible dragged material at the edge reveals the preview
  without dropping it. On a left/right Shelf edge, dragging a window there
  transfers it to that Workspace instead of opening the Shelf.
- Dropping new material on the preview inserts it at the start; continuing
  to drag inward expands the full Shelf so the user can pick an exact
  position.
- The keyboard shortcut cycles **closed → preview → full Shelf → closed**.
  Opening the preview focuses its first item; arrow keys follow the
  preview's axis, Enter expands the full Shelf on the focused item, Escape
  closes the preview.
- The preview shows the first items, in current order, as thumbnails or
  icons, then `+N` for the rest. Clicking an item opens the full Shelf with
  it selected — it doesn't open or copy it. Items can be dragged straight
  from the preview.
- The preview is thicker than the compact system bar; on the same edge it
  replaces the bar immediately, extending inward over windows without
  changing their layout. Closing it restores the bar; a bar on another edge
  stays visible.
- The full Shelf spans its edge on the current display as an inward
  overlay. Its inner edge is draggable and its size is remembered per user,
  per edge (default and limit dimensions are still deferred).
- New items insert at the start. Users reorder items by drag or by
  keyboard move-left/right; order and contents persist together until
  logout, and the preview follows the same order.
- The full Shelf uses a responsive grid: rows on a horizontal edge
  (scrolls vertically), columns on a vertical edge (scrolls horizontally).
- Arrow keys navigate the grid; Home/End jump to first/last. Click selects;
  Enter or double-click activates through the item's default handler —
  files, folders, and URLs open normally, text and image snapshots open in
  a viewer.
- Opening, copying, using, or dragging an item out leaves it in the Shelf —
  only explicit removal changes its contents.
- Only one Shelf overlay can be open at a time, and contents are global.
  Opening it on another display closes the previous overlay and reopens on
  the new one — never on every display at once. Clicking outside or Escape
  closes it.
- The open Shelf overlays windows and never resizes or changes the tiled
  layout. A foreground fullscreen window disables edge activation on that
  display, but the explicit keyboard shortcut still opens the Shelf above
  fullscreen.
- Stays open across Workspace switches, but closes (without losing
  contents) when Overview opens.
- Chat and the Shelf are independent and can stay open together, so items
  can be dragged into a conversation. With the default bottom Shelf on the
  same display, chat floats above its left side instead of becoming part of
  it; coexistence with a power-user edge is still unrefined.
- No item-count limit — the overlay scrolls when full. Snapshots share a
  configurable storage-size limit; existing items are never evicted
  silently. A snapshot that would exceed the limit is rejected with an
  explanation and a link to Shelf settings — file and folder references can
  still be added.

### Removal

- Removing one item is immediate and confirmation-free, with a brief
  **Undo**. Hovered or focused items show **Remove**; Delete removes the
  selected item.
- **Clear Shelf** removes everything immediately, also with a brief
  **Undo**.

## Notifications

ShapeBit notifications give visible, non-focus-stealing attention across
Workspaces. Privacy, lock-screen, sharing, critical-notification, and Do Not
Disturb constraints are owned by
Media, Privacy, and Notification Policy.

### Notification panel

- One global panel opens from an indicator on the right of the system bar.
  A click opens it on that button's display; the keyboard shortcut uses the
  focused window's display. Only one panel at a time.
- Clicking outside, Escape, or the indicator again closes it without
  clearing notifications.
- Grouped by app, newest group activity first, newest notification first
  within a group. A group shows its newest notification plus a count and
  expands to reveal older ones.
- The indicator badge counts unseen notifications; opening the panel marks
  the listed ones as seen without dismissing them.
- The header has a **Do Not Disturb** toggle; secondary-clicking the
  indicator gives the same quick toggle. Schedules are configured in
  Settings.
- Undismissed notifications persist locally across logout and restart,
  subject to a configurable retention period.

### Workspace routing

- A notification tied to a window belongs to that window's Workspace.
  Without a window, it belongs to the app's Workspace if all of that app's
  windows are in one Workspace.
- If the app spans several Workspaces or has no window, the notification is
  global — it doesn't mark every Workspace, and its banner shows on the
  focused window's display by default.
- A notification for the active Workspace shows a brief, non-focus-stealing
  banner by default. One for an inactive Workspace queues silently, marking
  its app icon and Workspace segment instead; per-app settings may allow a
  banner anyway. Banner behavior has a global default plus per-app
  overrides.
- Notification markers and app attention requests are separate: seeing a
  notification in the panel (or focusing its window) clears the marker, but
  a window's attention request stays until it's focused or the app
  withdraws it.

### Banners

- Appear beside the notification indicator — upward from a bottom bar,
  downward from a top bar, or (with the bar hidden by fullscreen) at the
  same configured corner.
- Up to three visible at once; extra notifications go straight to the panel
  until space frees up.
- Ordinary banners close after a configurable duration; hover or focus
  pauses the timer, and the notification stays in the panel afterward.
- Verified critical system notifications stay visible until explicitly
  handled or dismissed.

### Dismissal and policy

- Clicking a notification body runs its app-provided default action; for a
  window target, that switches to and focuses the window's Workspace
  without moving it.
- Inline actions leave the panel open; an action that opens or focuses a
  window closes the panel automatically.
- A banner's close control dismisses it from both banner and panel; an
  automatic timeout only hides the banner.
- Dismissing one notification, a whole app group, or **Clear all** acts
  immediately with a brief Undo. **Clear all** skips unresolved critical
  system notifications, which need individual handling.
- Do Not Disturb queues ordinary app notifications; apps can't bypass it —
  only the verified critical system path defined by
  Media, Privacy, and Notification Policy can. Fullscreen
  alone doesn't enable Do Not Disturb; sharing, locking, unlock summaries,
  and critical-system exceptions follow that same policy.

## Quick Settings

Quick Settings gives fast access to common system controls without
replacing the full Settings app.

### Panel basics

- One global panel. Clicking a system-bar status cluster opens it on that
  cluster's display; the keyboard shortcut uses the focused window's
  display. Only one instance at a time.
- Clicking outside, Escape, or the originating cluster again closes it
  without changing settings — applied changes stay, unsaved form edits are
  discarded.
- Always opens as one overview, never jumping to a section based on which
  icon opened it, with fixed groups **Connectivity**, **Privacy**, **Sound
  & Display**, and **Power**, each with its own heading. Reordering,
  search, pinning, and custom tiles are deferred to a future version,
  configured through the full Settings app.
- Bounded by display height — groups scroll inside the panel while the
  **Settings** button stays fixed and visible.
- Controls always reflect live system state, including changes from
  hardware, other apps, or other sessions.
- Tab/Shift+Tab move between controls; arrow keys work sliders and choices
  within a control; Enter/Space activates it. Closing the panel returns
  focus to whatever opened it. Every control has an accessible label, no
  distinction depends on color alone, and the panel supports text scaling,
  high contrast, reduced motion, and screen readers.
- Switches, sliders, and device choices apply immediately. A view with
  editable values needs an explicit **Save**, **Start**, or equivalent
  action — closing it discards unsaved edits, and any revealed secrets or
  QR codes hide again until explicitly reopened.
- A failed change reverts its control to the actual system state and shows
  an inline explanation that stays until the next attempt succeeds or the
  panel closes.
- An in-progress change shows a progress state and blocks repeat
  activation; closing the panel doesn't cancel it, and reopening shows its
  current or final state. A failure while the panel is closed becomes a
  normal [notification](#notifications); success stays silent.
- Unsupported hardware hides its control; a supported-but-temporarily-
  unavailable control stays visible, disabled, with an explanation.
- A persistent **Settings** button closes the panel and opens the full
  Settings app — switching to its window if one's already open, or opening
  one in the active Workspace otherwise.
- In a detail view, Escape returns to the overview; Escape again closes the
  panel.

### Connectivity

- **Wi-Fi**, **Bluetooth**, and **Airplane Mode** are switch tiles (Airplane
  Mode only where supported wireless hardware exists). Airplane Mode only
  touches wireless radios: it disables Wi-Fi and Bluetooth and stops an
  active hotspot, while Ethernet stays usable and VPN follows the remaining
  transport. Turning it off restores each radio's prior individual state
  without restarting the hotspot; radios can't be re-enabled individually
  while it's active.
- A wired connection shows a read-only Ethernet status row (state and
  network name); detailed configuration stays in full Settings.
- **Wi-Fi detail**: connect or disconnect without leaving the panel; a
  simple password enters inline, while certificate-based or advanced setup
  hands off to full Settings. Order: connected network, then saved
  networks, then others by signal strength. Each row shows connection
  state, signal strength, and security — no speed estimate, and no
  **Forget** action (that stays in full Settings).
- **Bluetooth detail**: connected devices, then paired, then newly
  discovered. Pairing, connect/disconnect, and PIN or passkey entry stay in
  the panel; a pairing failure shows an inline error without closing it.
  Discovery runs while the view is open; battery level shows only when
  reliably reported. No unpair action (full Settings).
- **Mobile Hotspot** (only on supporting Wi-Fi hardware): first use opens a
  detail view with a generated name and password; broadcasting starts only
  after **Start**. Name and password stay editable afterward, the password
  masked with reveal and **Copy** controls, and a QR code hidden until
  **Show QR code**. Changing the name or password while active requires
  confirming that connected devices will be dropped, then the hotspot
  restarts with the new credentials. The detail view lists connected
  devices with a per-device **Disconnect** (temporary — device blocking
  needs full Settings) and the overview tile shows a connected-device
  count. The hotspot keeps running through a locked session but stops at
  logout or restart.
- **VPN** tile appears once at least one VPN is configured. Its switch
  connects or disconnects the most recently selected VPN; the detail view
  picks another configured VPN. The tile shows the active profile name, a
  read-only **Kill switch** badge if enabled, and — depending on kill-switch
  status — a prominent **Reconnecting — network blocked** or **Reconnecting
  — traffic not protected** state (the compact system-bar VPN indicator
  mirrors these, plus hover text with the exact state). Only one active VPN
  at a time — selecting another disconnects the current one first; on
  failure, ShapeBit tries to restore the previous VPN and reports both
  failures if that also fails, stating explicitly that no VPN is active.
  Switching starts immediately, subject to the confirmation and
  authorization rules in
  Network Ownership and Privacy. Supported VPN
  types and system-wide routing are governed by
  Enterprise Network Authentication and the
  [architecture overview](Architecture).
- Cellular, NFC, other radio controls, and a dedicated captive-portal
  workflow are deferred; see
  Network Ownership and Privacy.

### Privacy

- **Camera** switch tile: **On** = camera available, **Off** = camera
  globally blocked for all covered apps, per
  Media, Privacy, and Notification Policy. If a controlled
  client keeps an active session while blocked, the unhideable privacy
  indicator stays visible, names the client, and shows it's blocked.
- Hardware microphone-mute and camera-shutter states override the software
  controls — when hardware blocks access, the matching software control is
  unavailable and labeled **Blocked by hardware**. Per-app permission
  management stays in full Settings.
- **Privacy activity** lists ongoing microphone, camera, screen-sharing,
  and remote-control use, ordered by sensitivity (remote control, screen
  sharing, camera, microphone; newest first within each type). Each entry
  shows the app, the resource or shared scope, and how long it's been
  active, with **Stop** wherever immediate revocation is supported per
  Media, Privacy, and Notification Policy. Stop acts
  instantly, revokes only that activity, and doesn't change the global
  Camera or microphone-mute controls. Stopping remote control leaves its
  screen-sharing session active; stopping screen sharing also revokes any
  attached remote-control session (the panel visually links such pairs).
  The list hides when nothing's active; no history is kept anywhere.
  Unhideable privacy indicators stay visible above Quick Settings itself
  regardless of whether the panel is open.

### Sound & Display

- **Volume** slider names and controls the current default output;
  hardware volume keys and external changes update it live. Its detail
  view picks another output device and lists per-app streams with
  independent volume and mute controls — an app drops off the list when
  its stream ends, but its setting is remembered for next time. Clicking
  the speaker icon toggles mute; unmuting restores the previous volume.
  Capped at 100% — no software amplification.
- **Microphone** input volume and device selection sit in the overview too,
  not just the audio detail view. Clicking the microphone icon toggles
  mute (**On** = input available, **Muted** = input globally blocked) —
  this is the same global mute defined by
  Media, Privacy, and Notification Policy, affecting apps and
  local-assistant voice input. As with Camera, an active client during a
  global mute keeps the unhideable indicator visible, naming the client.
- **Brightness** slider controls the display holding the panel; its detail
  view covers other displays whose brightness can be controlled reliably.
  Layout, scale, orientation, primary-display choice, and color calibration
  stay in full Settings.
- **Night Light** switch tile, off by default; its detail view sets color
  temperature and scheduling. First activation turns it on immediately
  without creating a schedule. When a schedule exists, a manual override
  lasts only until the next scheduled transition.
- **HDR** switch tile appears only if the panel's display supports HDR, and
  controls that display only; other supported displays get their own
  control in the detail view. While HDR is active, the detail view offers
  separate sliders for physical display brightness and SDR reference
  brightness. HDR state and safe SDR fallback are defined by
  Display, Power, and Thermal Policy.
- **VRR** control appears only if the panel's display supports variable
  refresh rate. Defaults to **Automatic for fullscreen** and can be
  disabled per display, per
  Display, Power, and Thermal Policy.
- If HDR, VRR, Night Light, or another selected mode can't safely combine
  on the current display pipeline, Quick Settings keeps the working
  configuration, disables the conflicting control, and explains why —
  it never silently degrades display state. Keyboard backlight and
  automatic-brightness controls are deferred.

### Power

- Battery-powered devices show percentage, charging state, and a
  remaining-time estimate only when the system considers it reliable for
  the main battery — a peripheral battery (such as a headset) stays with
  its own device controls instead. Alongside that sits a power-profile
  selector: **Balanced**, **Power Saver**, and **Performance** where the
  platform supports it, per
  Display, Power, and Thermal Policy. Low battery can
  auto-select **Power Saver — Automatic**, temporarily disabling the other
  profiles until external power restores the previous selection. Thermal
  throttling shows **Performance limited by temperature** (informational,
  can't be disabled). Battery conservation and charging-limit controls stay
  in full Settings because they're system-wide and may need administrator
  confirmation, per Display, Power, and Thermal Policy.
- **Power** opens a focused view of commands, not switches: **Lock** and
  **Suspend** act immediately; **Log Out**, **Restart**, and **Shut Down**
  require explicit confirmation that names known blocking apps and other
  active local/SSH sessions, and warns that unsaved work may not be
  reliably detected or preserved, with **Cancel** focused by default. When
  an update is staged, the relevant command may read **Restart and
  Update**, with confirmation and recovery behavior governed by
  Staged-Restart UX.

### System-bar status cluster

- The compact cluster prioritizes exceptional states — offline
  connectivity, a reconnecting VPN without protection, kill-switch-blocked
  traffic, global microphone mute, global camera block, low battery — over
  permanently showing every enabled feature.
- Hover text gives the exact state and the relevant device or profile
  name; critical distinctions use different icons or badges as well as
  color.

### Not in the initial release

- **Do Not Disturb** stays exclusively in the
  [notification panel](#notifications), not duplicated here.
- Accessibility shortcuts, appearance and theme selection, keyboard layout,
  location services, and similar controls stay in the full Settings app for
  now. If promoted later, they'll use the planned configurable-tile system
  rather than expanding this fixed panel.

## Assistant Framework

The assistant framework is the shared local foundation for assistant and
agent interaction across ShapeBit Desktop.

### Scope

- Voice and chat are two channels into the same framework, not separate
  assistants, and both run locally.
- The initial product has one global assistant agent, shared across all
  Workspaces and both channels. Context access, capabilities, privileges,
  and confirmations don't vary by channel.
- The agent has one serialized request queue shared by voice and chat;
  requests keep their source channel and run in arrival order.
- Cancelling the current request stops it, then lets the next queued
  request start — the rest of the queue is never silently discarded.
  Cancellation stops generation and asks an active action to cancel only if
  that action supports it; it never rolls back completed effects, and
  clearly reports when an action can't be interrupted.
- A non-interruptible action holds the queue until it finishes — later
  requests never run concurrently through the same agent.
- The system-bar assistant control shows current activity and queue depth,
  even while chat is hidden.
- Locking the session hides all assistant output. Already-authorized work
  may continue, but results surface only after unlock, and unstarted
  requests stay paused until then. Work that reaches a permission or
  confirmation step while locked pauses and shows its card only after
  unlock.

### Permissions and actions

- The assistant can read the current user's files, window contents, and
  clipboard by default, without per-item sharing — these read capabilities
  are granted to the initial agent up front, subject to the user's OS
  permissions and the framework's capability model either way.
- Permissions are assigned per agent and per capability, even while only
  one agent exists, from one central permissions surface that supports
  review and revocation.
- Write and control capabilities are off by default; ShapeBit asks for a
  capability on first use, and an approved grant persists until revoked.
- Agents call typed actions through controlled APIs and can't execute
  arbitrary shell commands.
- Reversible, non-destructive actions may run immediately. Destructive,
  privileged, or externally communicating actions require confirmation
  every time, regardless of standing capability grants.
- Capability grants and action confirmations must be approved on the
  visible card with pointer or keyboard input — spoken confirmation isn't
  sufficient in the initial design.

### History and memory

- The assistant surface keeps a local activity log of requested and
  completed actions, confirmations, and permission changes. Retention is
  user-configurable, and **Clear history** removes it immediately;
  discarded voice audio and transcripts are never included.
- Assistant memory persists locally across voice and chat sessions; users
  can view, edit, and clear it. Derived memories may survive a voice
  interaction, but raw audio and transcripts never do.

### Open questions

- Window-content access doesn't yet distinguish an app's semantic data from
  captured screen pixels. The accepted
  Media, Privacy, and Notification Policy requires a fresh
  portal grant for every screen-image capture, with no retention — so
  unrestricted pixel access isn't authorized unless a later decision
  supersedes that policy.
- Detailed capability scopes, the semantic-data/screen-pixel boundary,
  memory selection, and future agent isolation remain undecided.
  Cross-system authorization constraints are owned by the ShapeBit OS
  architecture docs.

## Assistant Chat

Assistant chat is the text interface to the shared
[assistant framework](#assistant-framework).

### Surface

- A global, on-demand overlay, not owned by a Workspace — an independent,
  frameless panel anchored bottom-left. It's not a pane inside the Shelf and
  doesn't use per-conversation chat-head icons.
- Opens from the system bar or a configurable shortcut; hidden when
  inactive. A bar click opens it on that button's display; the shortcut
  uses the focused window's display. Only one global chat panel is open at
  a time.
- Clicking outside focused chat reduces it to a passive three-bubble state;
  clicking outside again hides it. Escape or the close control hides it
  immediately. Hiding chat never ends the conversation or stops ongoing
  work; reopening restores the same conversation and position.
- Resizable from its top and right edges, size remembered per user; most of
  its area stays visually transparent.
- Doesn't hide the system bar on its own — chat sits just above a bottom
  bar, or at the bottom-left edge with a top bar.
- Chat and Shelf can stay open together. With the default bottom Shelf on
  the same display, chat moves above the Shelf preview immediately and
  further up when the full Shelf opens, returning as those close. Moving
  the Shelf to another display doesn't move an already-open chat panel;
  coexistence with a power-user Shelf edge is still unrefined.

### Bubble presentation

- Recent messages float as bubbles above a compact input; older messages
  stay available by scrolling within the overlay.
- Hovering or keyboard-focusing the overlay reveals a small header (current
  title, conversation list, new-conversation action, close control) and the
  input. Without hover or focus, only the three most recent bubbles remain
  visible.
- Clicking a passive bubble focuses chat, restores the input and header,
  and expands the full conversation around that message.
- The keyboard shortcut and the assistant system-bar icon share toggle
  semantics: hidden chat opens with the input focused; passive chat
  receives focus; already-focused chat hides.
- Focused and passive chat stay open across Workspace switches on the same
  display. Overview temporarily hides chat and restores its previous state
  when Overview closes; a foreground fullscreen window does the same on its
  display, though the explicit chat shortcut can still open chat above
  fullscreen.
- If chat is completely hidden, a new response never makes it appear
  automatically — the assistant system-bar control shows completion or
  attention instead. If chat is already open in its passive state, the new
  response may appear there.
- Responses stream progressively into one bubble; the Send control becomes
  **Stop** while a response or action is active. Escape hides chat without
  stopping the agent.
- The input stays usable during active work; sending another message adds
  it to the shared assistant queue rather than interrupting the current
  operation — queued items identify their source channel.
- Switching conversations never moves or cancels work; every queued request
  and result stays attached to its originating conversation while another
  conversation may be visible.

### Conversations

- Multiple conversations and their messages persist locally until deleted.
  Each has its own history, while assistant memory stays global across
  conversations.
- New conversations get locally generated, user-renamable titles.
- The conversation list sorts by latest activity and supports local search
  across titles and messages.
- Deletion is immediate and confirmation-free, with a brief **Undo**.

### Actions and confirmations

- Assistant tool and action requests appear as structured cards between
  message bubbles, showing pending, running, completed, or failed state
  rather than ordinary prose.
- A capability-permission request and an action confirmation are separate
  cards — granting a capability never also approves a destructive,
  privileged, or externally communicating action waiting behind it.
- A confirmation needed while chat is passive stays visible among the three
  passive items, with the assistant system-bar control marking attention;
  chat doesn't take focus automatically. If chat is hidden, only the bar
  attention state shows until the user opens it.
- A completed action card collapses to a compact result summary with
  expandable details; the full event also stays in the central assistant
  activity log defined by the shared framework.

Chat uses the same global assistant, memory, capabilities, privileges, and
confirmation rules as voice Assistant mode, all defined by the shared
[assistant framework](#assistant-framework).

## Voice Interaction

Voice interaction lets the user work with ShapeBit through local AI agents.

### Capture and privacy

- Push-to-talk only — there is no always-listening mode. Capture begins
  only after the explicit push-to-talk action and stops when the
  interaction ends.
- ShapeBit provides a default push-to-talk key or button, reconfigurable by
  the user (the exact default is still to be selected).
- The system bar shows a microphone indicator during capture; clicking it
  immediately cancels the interaction.
- Speech recognition and agent processing run locally — audio, transcripts,
  and agent requests are never sent to cloud services.
- Captured audio and transcripts are discarded after each interaction by
  default.
- Unavailable on the login screen, lock screen, and authentication prompts.

Microphone access and privacy indication remain subject to
Media, Privacy, and Notification Policy.

### Modes

The mode is explicitly selected, visibly indicated, and remembered per
user — never inferred from speech. **Assistant** is the initial mode for a
new user.

| Mode | What it does |
|---|---|
| **Assistant** | Sends the utterance to the local agent as a request. |
| **Speech to text** | Inserts a local transcription into the focused text input. |
| **Speech to text with translation** | Translates the local transcription and inserts it into the focused text input; the current input language is the default translation target. |

Assistant mode uses the shared
[assistant framework](#assistant-framework) also used by chat. Ordinary
responses are spoken through local text-to-speech by default; a per-user
setting may also show them temporarily as floating assistant bubbles, but
that presentation is disabled initially. Response text is discarded after
speech by default unless it contributes to a logged action or derived
memory.

- While speech output plays, the system bar shows an indicator; clicking it
  stops speech immediately without undoing completed actions. Pressing
  push-to-talk also stops current speech and begins a new capture
  immediately. Other playing audio is ducked rather than paused during
  assistant speech and restored afterward — configurable per user.
- A request queued behind existing work gets a short local acknowledgement
  sound and a queue-count update instead of a spoken status message.
- Locking the session stops assistant speech immediately. No assistant
  speech or visual output appears on the lock screen; results from
  continuing authorized work become available only after unlock.
- A voice request needing capability permission or action confirmation
  shows the same structured card as chat, via the assistant bubble overlay,
  even when ordinary response bubbles are disabled — without creating a
  persistent chat conversation or retaining the voice transcript. The
  resulting action event still lands in the central assistant activity log.

## Gaze Input

Gaze input is an optional way to position the pointer at the place where the
user is looking.

### Activation

- Enabled by default per user; can be disabled.
- Looking alone never moves the pointer or activates anything. An explicit
  keyboard key or mouse button moves the pointer to the latest stable gaze
  point without clicking — ShapeBit provides a default trigger the user can
  reconfigure.
- With a reliable point, the trigger moves the pointer immediately and
  shows a brief visual ripple at the destination.
- The destination is the measured gaze point; ShapeBit doesn't snap to
  nearby controls by default.
- The trigger does nothing during an active pointer drag or resize, so it
  can't move something unexpectedly.
- The system bar shows a privacy indicator whenever tracking is active,
  with direct pause and resume controls.

### Data boundary

- Camera frames and derived gaze data stay local and transient — only the
  latest stable gaze point is held in memory. Apps and agents can't access
  frames, gaze data, or that point.
- Tracking stops on the login screen, lock screen, and authentication
  prompts, and resumes only in the unlocked user session.

Camera access and privacy indication remain subject to
Media, Privacy, and Notification Policy.

### Calibration and reliability

- First login with supported hardware offers guided calibration. It may be
  skipped, but tracking stays paused until calibration succeeds.
- Without supported gaze hardware, the feature stays inactive without
  repeated prompts or error indicators; Settings shows it as unavailable.
- Triggering without a reliable point leaves the pointer in place and shows
  a brief recalibration notice. Sustained low confidence pauses tracking
  and offers recalibration instead of repeating notices.
- Calibration is stored separately for each display, and the pointer may
  move directly between calibrated displays. Looking at an uncalibrated
  display doesn't move the pointer and offers calibration instead.
- A display-position, orientation, scaling, or physical-setup change that
  makes stored calibration unreliable pauses tracking for that display
  until it's recalibrated.

The exact default binding, stability and confidence thresholds, and
detailed recalibration flow are still to be selected.
