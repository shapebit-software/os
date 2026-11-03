# Desktop Environment

ShapeBit's desktop runs on **Hyprland** (the compositor) and **Quickshell**
(the shell: the bars, panels, Settings, and the lock screen), in a session run
by **UWSM**. Its design follows the
[demo](https://shapebit.software/demo/); where this page and the demo
disagree, the demo decides. The source is the
[desktop repository](https://github.com/shapebit-software/desktop).

This page has two parts: the [desktop as built](#the-desktop-as-built), and
the [future design](#future-design) of features that are not built yet.

## The desktop as built

### Session

- The login screen (SDDM) offers one session, ShapeBit. UWSM starts Hyprland
  and runs the session's systemd units: `graphical-session.target` and the
  applications that start with every session (XDG autostart).
- Homes are systemd-homed homes; the login password unlocks the home and the
  secret service (gnome-keyring).
- The shell is the session's notification server and polkit agent: when an
  application asks for an action that needs an administrator, the shell asks
  for the password, in the lock screen's style.
- The shell is also the session's agent for NetworkManager and BlueZ: a
  network's password, when the saved one fails or none was kept, and a
  Bluetooth device's pairing code, to compare, type, or type on the device,
  show as questions in the portals' style.
- Applications share the screen through Hyprland's portal, which asks
  what to share through the capture overlay: a selection, a window, or a
  screen, as for a screenshot. Screenshots that applications ask for go
  through the capture overlay too, screenshots only.
- The shell's portal answers everything else applications ask of the
  desktop, Flatpak ones included; gnome-keyring's keeps their secrets.
  What needs the person shows as a **question**, centered over everything
  with the screens dimmed, in the file chooser's style: whether an
  application may do something, such as use the camera, with the choices
  it offers; which application opens a file or a link; whether to share
  the person's name and picture, let an application with no windows go on
  in the background, add a launcher to Apps under a name the person can
  change, or set a picture as the wallpaper, previewed. Questions wait
  their turn. Enter grants, Escape dismisses.
- Applications' notifications reach the shell's notification server
  through the portal too; a click runs the application's action. Keeping
  the screen awake or the computer from sleeping goes to logind, which
  hypridle follows. The settings applications read are GNOME's, such as
  the window buttons, with the shell's accent.
- Printing and email are not offered yet.
- Applications open and save files through the shell's **file chooser**, a
  portal: GTK ones and those in Flatpak. It shows centered over everything,
  with the screens dimmed: the places (Home and the person's folders) on the
  left; the folder's path, its files and folders, the application's filters,
  and the buttons on the right. A double click opens a folder or chooses a
  file; saving asks for a name, and asks before replacing a file.
- Copied text stays available after the application it came from closes;
  only the last copy is kept, in memory for the session, never on disk.

### Bars

- Two bars: the **system bar** (the clock and the status items) and the
  **dock** (Apps, the workspace maps, and the quick actions). Each sits on
  any edge of the screen, and each has three zones — start, center, and end
  — whose items can move between the bars (Settings > Shell).
- The system bar's items each open a panel beside them:
  - **Notifications** — the notifications kept, newest first, with Do Not
    Disturb and **Clear all**. A dot on the bell marks new ones.
  - **Microphone** and **Sound** — the device, its volume, and mute; a right
    click on the item mutes it.
  - **Brightness** — the built-in display's brightness, shown only where the
    computer has a backlight. The brightness keys change it too.
  - **Network** — the connection in use, Wi-Fi, and Bluetooth. A click on
    Wi-Fi unfolds the networks in reach: the one in use first, then those
    known, then by signal, each with its signal and a lock if secured. A
    click joins one; a secured one not known first asks its password in its
    row. A click on Bluetooth unfolds the devices, paired first, then those
    nearby: a click pairs, connects, or disconnects one. Settings > Network
    has the same lists, and forgets networks and devices.
  - **Input language** — the keyboard layouts to switch between
    (Super+Space, Super+Shift+Space back).
  - **Battery** — shown only on computers with a battery: the charge on the
    item, its percentage beside it (Settings > Shell), the time left on
    hover, and the power profile (Power Saver, Balanced, and Performance
    where available) in its panel.
  - **System menu** — who is signed in, Settings, and Lock, Suspend,
    Restart, Shut down, and Log out. Restart, Shut down, and Log out ask
    first, with Cancel focused.
- One panel is open at a time. Escape or a click outside closes it.

### Notifications

- New notifications show as banners in the top right corner of the focused
  screen, below a top system bar, newest on top. A banner goes after the
  application's time or five seconds and stays while the pointer is on it;
  critical notifications stay until dismissed. Banners are hidden while a
  panel is open.
- A click on a notification runs its default action; its cross dismisses it.
  Notifications whose banner has gone stay in the panel until dismissed.
- Do Not Disturb holds back the banners of all but critical notifications;
  the notifications are kept all the same.

### Workspaces

- There is no Overview. The session starts with one workspace. While a
  window or an application is dragged, the dock shows a "+" after the
  workspace maps; a drop there makes a new workspace, up to eight. A
  workspace without windows goes away: when the one on screen loses its last
  window, the screen moves to the next one.
- Each workspace has a **map** on the dock: its windows where they are on
  the screen, with their applications' icons.

### Windows

- Windows tile in the workspace's layout: **Lead**, **Dwindle**,
  **Columns** (the default for new workspaces, Settings > Windows),
  **Center**, **Grid**, **Rows**, **Tabs**, and **Accordion**. The layout
  menu on a map shows the layouts that suit its number of windows.
- Tabs and Accordion show one window at a time: Tabs with a tab bar above
  it, Accordion with the others folded thin beside it.
- With the pointer, windows move only on the maps: a window's cell dragged
  onto another cell swaps them, and onto another map moves the window
  there. There are no window title bars to drag. The keyboard moves them
  too ([Keyboard shortcuts](#keyboard-shortcuts)).
- Applications show no window buttons (close, minimize, maximize) in the
  title bars they draw themselves: the system's default button layout is
  empty, so GTK and libadwaita applications, and those that follow them,
  leave them out. Applications that ignore it, such as Electron ones, keep
  their own.
- The handles between tiles resize them.
- A window takes the keyboard when clicked.
- Full screen (Super+F, or a double click on its cell) covers the bars; a
  button in the top right corner ends it. Super+Q, or a right click on its
  cell, closes a window.

### Apps and quick actions

- **Apps** lists the installed applications ten to a page, with a search. A
  click opens an application on the current workspace; dragged onto a map,
  it opens there.
  A right click offers an application's details and, for a Flatpak, removing it,
  both in Settings > Apps.
- The **quick actions** open from buttons on a bar or from a hot corner
  (Settings > Shell). The assistant button is a placeholder that says it is
  coming.
- **Dictation** starts from its quick action or Super+D (a tap starts and stops;
  held, it listens until let go). It writes into the app the person is in; the
  assistant is a separate thing with its own button. The button's icon shows the
  state: bars following the microphone, a pencil while writing it down, lines
  while the text waits, red when something is wrong; its tooltip says the rest.
  With no button (a hot corner, or the button turned off), a pill does this
  instead, so an open microphone is never out of sight. The language follows the
  keyboard layout, is any of Parakeet's 25, or is any of Whisper's 100, per layout
  (Settings > Language). It says
  when the microphone hears nothing or the person seems gone, and stops by
  itself after a long silence.
  - **Writing it down.** With Parakeet downloaded (an
    [extra](#extras)), in its 25 languages, `dictation/dictate-engine` writes it down while the person speaks, and a draft shows in the corner, with
    the words that may still change faint. The draft goes nowhere else: nothing
    enters an application before the stop, and the pointer passes through it. At
    each pause Silero cuts a phrase, and at the stop only the last one is left, so
    the text comes at once. Parakeet hears all the audio, as Silero can take a
    short phrase for silence. Without it, in other languages, with all of Whisper's
    chosen, or should the engine fail, Whisper writes down the whole recording at the stop.
  - **Where the text goes.** While it runs, `dictation/dictate` is the Wayland
    input method, so applications tell it when a text field has the focus, and
    of what kind. If the same field has the focus at the stop and when the text
    is ready, the text goes straight in, as text rather than keys, so it cannot
    press shortcuts. Otherwise it waits in a card, which never goes away by
    itself: moving elsewhere while it is written down, no field, no window, a
    password field, or a window that does not tell (XWayland, or another input
    method running).
  - **The card** offers Insert when a field has the focus, Copy, Type (keys, only
    when asked), Keep talking, which adds to the text, and Discard; a click on
    the text corrects it. It leaves the application its focus; the shortcut goes
    to the card, for the keyboard.
  - **Password fields** never get dictated text, by either way in.
  - **Recovering.** If Whisper fails, the audio stays for Try again until
    discarded. A right click on the button brings back the last dictation.
  - **Privacy.** Parakeet and Whisper run on the computer; audio is in the runtime directory
    and goes when the dictation ends. Locking the screen discards everything
    under way, and the last dictation.
- Capturing opens the **capture overlay**: the screen dims, with a panel at
  the bottom center, in one row of icons named by their tooltips:
  Selection, Window, or Screen; a switch between a
  screenshot and a recording whose knob, with the camera or the video
  camera in it, is the capture button and slides to the side clicked; and
  the options of the kind chosen: **Edit before saving** for screenshots,
  or the timer (none, 3, or 10 seconds, shown in a badge) and **Mic** (the microphone's
  sound) for recordings. Edit and Mic are kept in the settings. Cancel sits on the panel's top right corner; until something
  is picked, the middle of the screen says what to do. A drag draws the
  selection, which shows its size in pixels, moves from inside, resizes
  from its corners, and is kept for next time; in Window, a click picks a
  window. The capture button or Enter captures. During the timer only a
  countdown shows, and the screen stays usable.
- A screenshot is saved to Pictures/Screenshots at once, and the screen
  flashes where it was taken. With Edit before saving on (kept in the
  settings), it first shows for **markup**: arrows, highlights, pixelated
  areas, numbered circles, and text (a click on a text edits it), in red,
  yellow, blue, black, or white; **Move**, which picks a mark to drag
  elsewhere or delete (the bin, or Delete); and Undo and Redo, which step
  through every change. **Save** (Enter)
  saves it, **Copy** puts it on the clipboard, and the close button on the
  bar's corner cancels. Recordings go to
  Videos/Recordings; while recording, the capture button is red with the
  recording's length, and one click on it stops it at once.
- When an application shares the screen, the capture overlay opens on the
  focused screen, its panel with **Share** in place of the switch and
  **Remember**, kept in the settings, which lets the application share the
  same thing again without asking. Enter shares; Escape or the close button
  cancels. While anything is shared, the capture button is filled with the
  accent and shows a screen, and its tooltip names the applications it is
  shared with. Sharing stops from the application.

### Keyboard shortcuts

- Super moves the focus; with Shift, the focused window goes along. The
  arrows go to the tile beside, and past the last one to the screen beside;
  in Tabs and Accordion, left and right go through the windows in order.
  With Alt, the left and right arrows go to the workspace before or after;
  the numbers go to a workspace by its place on the strip.

| Shortcut | Action |
|---|---|
| Alt+Tab, Alt+Shift+Tab | Switch window |
| Alt+\`, Alt+Shift+\` | Switch among the application's windows |
| Super+arrows | Focus the tile, or the screen, beside |
| Super+Shift+arrows | Swap with the tile beside, or move to the screen beside |
| Super+Alt+←/→ | Previous or next workspace |
| Super+Alt+Shift+←/→ | Move the window to the previous or next workspace |
| Super+1…8 | Workspace by its place |
| Super+Shift+1…8 | Move the window to a workspace by its place |
| Super+Q | Close the window |
| Super+F | Full screen |
| Super+W | Window menu |
| Super (alone) | Apps |
| Super+N | Notifications |
| Super+I | Settings |
| Super+L | Lock |
| Ctrl+Alt+Delete | System menu |
| Super+Space, Super+Shift+Space | Next or previous keyboard layout |
| Super+/ | Keyboard shortcuts |
| Print | Capture overlay |
| Alt+Print, Super+Print | Capture overlay on the focused window, or on the screen |
| Shift+Print | Capture overlay for a recording; stops one going on |
| Media keys | Volume, mute, microphone mute, play and tracks, brightness |

- The **window switcher** lists the windows of every workspace and screen,
  the most recently focused first, so a quick Alt+Tab goes back to the
  window before; it shows after a moment. The picked window is lit on its
  map. Letting go of Alt, Enter, or a click focuses it, and the screen moves
  to its workspace; Q closes it; Escape cancels. Alt+\` lists the windows of
  the focused window's application, or, while switching, of the picked one's.
- Moving a window past the last workspace, or to the number after it, makes
  a new workspace, up to eight. The keys work by their place on the
  keyboard, whatever the layout.
- The **window menu** opens over the focused window: full screen, moving it
  to another workspace of its screen, a new one, or another screen, the
  workspace's layout (left and right change it), and closing it.
- **Keyboard shortcuts** shows a keyboard with what each key does with the
  modifiers chosen above it, or held down, and the media keys.
- On the lock screen, only the sound, media, and brightness keys work.
  Alt+F4, Alt+Space, Ctrl+Space, F11, and the applications' own shortcuts
  are left to the applications.

### Lock, idle, and sleep

- The lock screen looks like the login screen, whatever the wallpaper: the
  date, time, and system menus along the top, and in the middle who is signed
  in and the password field.
- The screen locks after the idle time set in Settings > Account (1 or 5
  minutes, or never) and before the computer sleeps; sleep waits for the
  lock. The screens turn off after their own idle time (2 or 10 minutes, or
  never) and come back on with input or after sleep. hypridle carries this
  out.

### Settings

- Settings covers the screen it opens on, with sections in groups and a
  search across them: **Account** (picture, name, password, idle times,
  Welcome again),
  **Assistant** (a placeholder), **Language** (the system language, the
  region format, keyboards), **Time** (time zone, automatic time, time
  format), **Desktop** (accent color, wallpaper), **Shell** (the bars and
  their items, the bar background, the quick actions, the battery
  percentage), **Windows** (corners, decoration, gaps, the default layout),
  **Display** (with more than one display, their arrangement, dragged
  into place, the primary display, where the session starts, and mirroring;
  each display's resolution, scale, and refresh rate), **Mouse** (tap to
  click and natural scrolling on the touchpad, shown only where the
  computer has one; natural scrolling on a mouse; and each one's speed),
  **Network**, **Sound**, **Apps** (a store: all apps or only the installed, with
  a search and categories, each with its details and what it can reach;
  [Applications](Architecture-Applications.md#installing-apps)), **Downloads**
  ([below](#downloads)), and **Updates**
  (the running system's version, the
  state of system updates with **Check now**, and the daily app updates).
- Settings for the whole computer — the system language, the time zone, and
  automatic time — ask for an administrator's password. The system language
  applies from the next sign-in.
- Settings has only what works. Not built yet: the first day of the week,
  dragging tabs, and keeping tile sizes across sessions.

### Updates

- The system checks for a new system image in the background and downloads
  it ([Lifecycle](Architecture-Lifecycle.md#checking-for-updates)). Once one is
  ready, a notification says so, once per version, and **Restart** in the
  account panel reads **Restart to update**. The next restart or shutdown
  installs it; nothing restarts by itself.
- A version reads as its build date and commit, such as
  "30 October 2026 · e0920a".
- Apps installed from Flatpak, the browser included, update daily in the
  background; a running app gets its update the next time it opens.

### Downloads

Everything the desktop downloads and installs goes through one queue: the
browser and apps from Welcome, installing and removing apps in Settings >
Apps, extras, the dictation models among them, from Welcome and Settings >
Assistant, and the daily app updates, so an update never runs alongside an
install. One job runs at a time, in a systemd user service of its own
rather than in the shell, so it goes on if the shell restarts. What a logout
or restart stopped starts again at the next sign-in. A target has one job at
a time, so asking twice does nothing.

**Settings > Downloads** lists it all: what is under way first, with how far
it is, then what ended, newest first. Each job can be cancelled while it waits
or works, and tried again once it failed or was cancelled; **Clear finished**
forgets what ended. While anything waits or works, a button on the system bar
opens it. A cancelled extra keeps what it downloaded, and its next try goes on
from there. An app install that fails or is cancelled removes what Flatpak
fetched for it that no app uses, such as its runtime.

### Extras

Extras are what is too large for the OS image and not everyone needs, such as
speech and language models. `extras/extras.json` lists them, with the hash of each
download; adding one is adding an entry. Welcome offers them when online, kept unless
turned off, and Settings > Assistant downloads and removes them later. They go to
`/var/lib/extras`, for everyone on the computer, and only administrators may change
them. They stay private: nothing is sent, only downloaded. A download goes on where
it stopped, and an extra appears only when whole and correct. In `/var`, they are not
in the sealed image, so the OS needs none of them and updates without them.

### Welcome

Each person's first login opens Welcome, full screen over the desktop on
the primary display. It asks only what the installer didn't, in six steps:

1. **Network**: only when the computer was offline when Welcome opened,
   with the network panel's Wi-Fi list and inline password.
2. **Browser**: the default browser
   ([Internet Browsers](Architecture-Applications.md#internet-browsers)), only
   when online. Nothing is picked at first, and none may be.
3. **Recommended apps**
   ([Recommended Apps](Architecture-Applications.md#recommended-apps)), only
   when online: all on, each with a switch to leave it out.
4. **Optional downloads** ([Extras](#extras)): only when online, with something
   to download, for administrators: all on, each with a switch to leave it out.
5. **Installing**: only when something was chosen. Steps 2 to 4 only record
   the choices; this step adds them all to the [queue](#downloads), the
   browser to be the person's default, and shows how each goes. **Back**
   cancels what has not finished. **Next** waits until everything is in, and
   offers **Try again** for what failed.
6. **Getting around**: Super for Apps, workspaces, moving between windows,
   and Super+/ for every shortcut.

**Skip all** ends Welcome on any step, and what is installing goes on;
nothing blocks the desktop. Once finished or skipped, Welcome doesn't open
again on its own; Settings > Account opens it again.

If Welcome closes without the computer having been online, so without the
browser and apps steps, the first time it is online afterwards a notification
says **Finish setting up**. Opening it opens Welcome at the browser step;
dismissing it ends it. It appears once.

## Future design

Nothing in this part is built yet, except dictation's plain speech to text
(see above). The assistant and its Settings section are placeholders in the
desktop as built.

### Radial Context Menus

ShapeBit-owned context menus use a radial ("pie") layout instead of a
traditional vertical list.

#### Scope and ownership

- Required across the ShapeBit shell and first-party apps.
- The shell owns menus for Workspaces, window chrome, the system bar,
  the Shelf, notifications, and other shell surfaces.
- First-party apps use a shared ShapeBit radial-menu component but own
  their own actions.
- Third-party Wayland apps keep their own in-surface context menus; ShapeBit
  doesn't intercept or replace them, and can't add, remove, or reorder their
  actions until ShapeBit defines a trusted extension model.
- The menu's owner captures its target object when it opens and re-validates
  that target before running an action, so a stale menu can't act on
  something since removed or changed into an incompatible state.

#### Activation and execution

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

#### Layout and stable positions

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

#### Secondary levels

- A category wedge shows a visible outward indicator. Clicking it swaps the
  current ring for its secondary level at the same center.
- During a held gesture, crossing a category wedge's outer edge opens its
  secondary level without releasing — the user can continue into that level
  and release to act.
- Only one ring shows at a time; a secondary level's center shows the
  category name and **Back**. Moving to center, clicking **Back**, or
  pressing Backspace returns to the parent level. Escape closes the whole
  menu. Opening a secondary level never depends on a hover delay.

#### Screen-edge placement

- The ring normally opens around the click point. If it would cross a
  display edge, the whole ring shifts inward just enough to stay visible —
  sectors don't rotate or reorder. A subtle connector marks the original
  activation point when the ring moves.
- The pointer is never warped. After an edge shift, pointer motion is
  ignored until it enters the shifted center's neutral zone, so the initial
  offset can't accidentally select something — this can mean one extra
  movement near an edge.

#### Keyboard, touch, pen, and accessibility

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

#### Visual feedback

- The center shows the captured target or current category, plus
  **Cancel** or **Back**. The selected wedge gets a clear outline and
  slight expansion.
- Destructive actions use both a warning icon and color; disabled actions
  stay readable but muted.
- Opening and level changes use a short fade-and-scale transition; reduced
  motion drops the movement for an immediate fade.
- Exact radius, typography, spacing, target size, colors, and animation
  timing belong to the ShapeBit visual-system spec, not this document.

### Shelf

The Shelf is a temporary, user-controlled place to keep material close at
hand while working across Workspaces.

#### Scope and contents

- Global to the user, not owned by any Workspace, and cleared at logout.
- Items enter only through an explicit action (drag, **Send to Shelf**) —
  clipboard contents are never captured automatically.
- Files and folders stay as references; the Shelf doesn't copy or move
  them, and drops an item silently if its source disappears.
- Text, images, and URLs become Shelf-owned snapshots. Removing a Shelf
  item never touches the source data.

#### Presentation and capacity

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
- Stays open across Workspace switches.
- Chat and the Shelf are independent and can stay open together, so items
  can be dragged into a conversation. With the default bottom Shelf on the
  same display, chat floats above its left side instead of becoming part of
  it; coexistence with a power-user edge is still unrefined.
- No item-count limit — the overlay scrolls when full. Snapshots share a
  configurable storage-size limit; existing items are never evicted
  silently. A snapshot that would exceed the limit is rejected with an
  explanation and a link to Shelf settings — file and folder references can
  still be added.

#### Removal

- Removing one item is immediate and confirmation-free, with a brief
  **Undo**. Hovered or focused items show **Remove**; Delete removes the
  selected item.
- **Clear Shelf** removes everything immediately, also with a brief
  **Undo**.

### Assistant Framework

The assistant framework is the shared local foundation for assistant and
agent interaction across ShapeBit Desktop.

#### Scope

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

#### Permissions and actions

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

#### History and memory

- The assistant surface keeps a local activity log of requested and
  completed actions, confirmations, and permission changes. Retention is
  user-configurable, and **Clear history** removes it immediately;
  discarded voice audio and transcripts are never included.
- Assistant memory persists locally across voice and chat sessions; users
  can view, edit, and clear it. Derived memories may survive a voice
  interaction, but raw audio and transcripts never do.

#### Open questions

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

### Assistant Chat

Assistant chat is the text interface to the shared
[assistant framework](#assistant-framework).

#### Surface

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

#### Bubble presentation

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
  display. A foreground fullscreen window temporarily hides chat on its
  display and restores its previous state afterwards, though the explicit
  chat shortcut can still open chat above fullscreen.
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

#### Conversations

- Multiple conversations and their messages persist locally until deleted.
  Each has its own history, while assistant memory stays global across
  conversations.
- New conversations get locally generated, user-renamable titles.
- The conversation list sorts by latest activity and supports local search
  across titles and messages.
- Deletion is immediate and confirmation-free, with a brief **Undo**.

#### Actions and confirmations

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

### Voice Interaction

Voice interaction lets the user work with ShapeBit through local AI agents.

#### Capture and privacy

- Push-to-talk or a click to start and stop — there is no always-listening mode. Capture begins
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

#### Modes

There are no modes to select or remember: the two buttons say where the words
go, so nothing can land in the wrong place because a mode was forgotten.

| Button | What it does |
|---|---|
| **Sparkle** | Holding it, or its shortcut, sends the utterance to the local agent as a request. A click opens chat, which also has a microphone. |
| **Waveform** | Dictation, as built: writes into the app the person is in (see above). |

Translation is a request to the assistant.

Talking to the assistant uses the shared
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

### Gaze Input

Gaze input is an optional way to position the pointer at the place where the
user is looking.

#### Activation

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

#### Data boundary

- Camera frames and derived gaze data stay local and transient — only the
  latest stable gaze point is held in memory. Apps and agents can't access
  frames, gaze data, or that point.
- Tracking stops on the login screen, lock screen, and authentication
  prompts, and resumes only in the unlocked user session.

Camera access and privacy indication remain subject to
Media, Privacy, and Notification Policy.

#### Calibration and reliability

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
