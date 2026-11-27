# ShapeBit Desktop

The desktop of ShapeBit OS: [Hyprland](https://hypr.land) as the compositor
and [Quickshell](https://quickshell.org) as the shell, following the
[demo](https://shapebit.software/demo/), which decides where this README
and the demo disagree. What a person sees is in the
[guidebook](../../guidebook/Desktop.md).

The session starts Hyprland through [UWSM](https://github.com/Vladimir-csp/uwsm),
which runs the session's systemd units (`graphical-session.target` and the
applications that start with every session, XDG autostart), with the
configuration in `compositor/`; the shell in `shell/` is one of those units,
`shell.service`.

The shell draws the wallpaper, the system bar and the dock (Apps, the
workspace maps, and the quick actions) with their panels, the tabs of the Tabs
and Accordion layouts, the handles that resize tiles, the way out of full
screen, Settings, and the lock screen. Beyond the demo, the system bar has
notifications (banners, and a panel with them by app, the downloads, and Do
Not Disturb), the display's brightness, and the battery with the power
profile, these two only where the computer has them, and the icons of the
applications running in the background, in the middle of the bar unless
moved: side by side, or stacked until the pointer is on them (Settings >
Shell); a click on one does what its application does for it, and a right
click opens its menu. The shell is also the session's polkit agent, which asks
for an administrator's password, its notification server, and, through the
portals, what applications ask: the file chooser, screenshots and what to
share in the capture overlay, and questions such as permissions, which
application opens a file, the person's details, running in the background,
launchers, and the wallpaper (the backends in `portal/src/portal` and
`portal/src/share-picker` hand it their questions). The portal backend also
passes applications' notifications to the shell, keeps the computer awake
through logind, and gives applications their settings. Captures from the quick
actions open the same overlay, with a panel of one row of icons: a
selection, a window, or the screen; a switch between a
screenshot and a recording whose knob is the capture button; and editing for
screenshots, or a timer and the microphone for recordings; screenshots are saved at once, or, with editing, first open for
markup. When an application shares the screen, the overlay's panel has Share
in place of the switch, and Remember, which lets the application share it
again without asking; while sharing, the capture button is filled with the
accent. It runs
hypridle, which locks the screen and turns it off after the idle times in
Settings and locks it before the computer sleeps, and clipman, which keeps
copied text after the application it came from closes. Settings are kept in
`~/.config/desktop/settings.json`; the shell applies them to itself and to the
compositor. The displays' settings, their arrangement, mirroring, the primary
display, and each one's mode and scale, are also kept as monitor rules in
`~/.config/desktop/displays.lua`, which the compositor runs as it starts.

Dictation (`dictation/`, Super+D) writes speech into the application in use,
and the assistant (`assistant/`, Super) answers and acts through typed
actions; both run on the computer, with their larger models as extras
(`extras/`).

Each bar can sit on any edge, and its items can move between the bars' zones
or off the bars, hidden, all but the system menu; buttons on the dock can be
half size, two to a slot (Settings > Shell, over `shell/src/services/bars.js`). With the pointer, windows move only on the maps: drag a window's cell onto
another cell or map; double-click it for full screen (Super+F), which covers
the bars and ends from the button in the top right corner; right-click it to
close it (Super+Q).

The keyboard shortcuts are in `compositor/shortcuts.lua`, each with a
description; Super+/ shows them on a keyboard. Super moves the focus and,
with Shift, the window: the arrows to the tile or screen beside, Alt with
the arrows to the workspace before or after, and the numbers to a workspace
by its place. Alt+Tab opens the window switcher, Super+W the window menu,
Super+A Apps, and Super alone the assistant: a tap opens it, and held, it
listens.

Unlike the demo, the desktop has no Overview: workspaces come and go with
their windows. The session starts with one; dropping a window or an
application on the "+" that the strip shows while dragging makes another, up
to eight; a workspace goes away once it has no windows.

## Development

`make lint validate` checks the shell and the compositor's configuration;
`make simulate` shows the shell in a window, on fake system services, and
`make sync` puts a change into a running ShapeBit, the VM or this computer;
`make watch` does either at every save, and the shell reloads in place
([development](../../development/README.md)).

Each folder of `shell/` is a QML module, `qs.<folder>`. Every QML file must be
listed in its folder's `qmldir`, and a file imports the other folders it uses.

## Layout

The desktop is several features of [`packages/`](../), each a folder and a
package:

| Feature            | What it holds                                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `shell/` (here)    | The Quickshell configuration (QML): `services/` (singletons that hold state, with their tests), `controls/`, `wallpaper/`, `bar/`, `windows/`, `settings/`, `lock/`, `capture/`, `notifications/`, `dialogs/`; and `features/`, where other packages add theirs (below). |
| `windows/`         | The Hyprland configuration (Lua): look, key bindings, layouts and resizing, workspaces; the session entry that the login screen starts, and the window button defaults. |
| `portal/`          | The shell's portal backend, the portals' configuration, and the share picker, which Hyprland's portal asks.     |
| `network/`         | The connection agent.                                                                                            |
| `sound/`           | Sound, and the bar's microphone level.                                                                           |
| `apps/`            | The helpers of Welcome and Settings > Apps, and the timer that updates the apps.                                 |
| `assistant/`       | The assistant's service, its actions and skills, the model catalog, the units that run it and `llama-server` on demand, `llama-server` itself (an external package), and its user interface, the module `qs.assistant`. |
| `downloads/`       | The one queue of downloads and installs, which Settings > Downloads shows, and the unit that resumes it at sign-in. |
| `dictation/`       | Dictation: `hear` turns speech into words, for dictation and the assistant; `dictate` is the input method that delivers them; sherpa-onnx (an external package). |
| `extras/`          | The extras (large optional downloads, such as models) with their hashes, the helper that installs them, and their license texts. |
| `licenses/`        | The reader of Settings > Licenses: each component's texts, from `/usr/share/licenses` and the RPM database.     |

Development tools are in [`development/`](../../development/README.md).


**Features add to the shell.** A feature's package installs its QML as the
module `qs.FEATURE` in the shell's folder, and `features/FEATURE.qml`, a
[Feature](src/services/Feature.qml): its Settings sections and pages, rows
for the shell's sections and pages, its items for the bars, its panels, what
it shows on every screen, its quick actions for the hot corner, its keyboard
shortcuts, and what it does for other features. It keeps its settings in its
own `~/.config/desktop/FEATURE.json`, through
[SettingsFile](src/services/SettingsFile.qml), as the shell keeps its own.
[Features.qml](src/services/Features.qml) loads them, so the shell names no
feature; the assistant is the first
([packages/assistant](../assistant/README.md)). openQA checks that the shell
logs no QML errors.
## Not yet implemented

- The assistant reads no files' contents and no clipboard. Dictation needs
  Parakeet, an extra, downloaded from Welcome or Settings > Assistant
  (`extras/`); the OS image has sherpa-onnx.
- Settings has only what works: no first day of the week.
- Tabs cannot be dragged.
- Tile sizes last while the workspace keeps its layout, not across sessions.

## Planned

- **Radial context menus** for the shell and ShapeBit's own apps; others keep
  theirs. They open on the secondary button, the Menu key, or a long press;
  press, move into a wedge, and release runs it, and releasing in the center
  keeps the menu open. At most eight wedges, each in a fixed direction for its
  kind of object, never reordered: the primary action on top, destructive ones
  in a consistent lower sector; unavailable ones stay, disabled; at most two
  levels. Near an edge the ring shifts inward, never the pointer. The keyboard
  works throughout, nothing depends on color, motion, or speed, and the menu
  never times out.
- **Shelf**: a temporary place for things across workspaces, cleared at
  logout. Only explicit actions add to it (a drag, **Send to Shelf**), never
  the clipboard; files stay references, other things become copies under one
  size limit, never evicted silently. It opens from a screen edge or a
  shortcut, over the windows, and removing has Undo.
- **Gaze input**: a key or button moves the pointer to the latest stable gaze
  point; looking alone never moves or clicks anything. Camera frames and gaze
  data stay in memory, unreadable by apps and the assistant; an indicator
  shows while tracking, which stops on the login and lock screens. It needs
  calibration per display.
