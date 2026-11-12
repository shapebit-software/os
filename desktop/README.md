# ShapeBit Desktop

The desktop of ShapeBit OS: [Hyprland](https://hypr.land) as the compositor
and [Quickshell](https://quickshell.org) as the shell, following the
[demo](https://shapebit.software/demo/). Where the demo and the
[Desktop Environment](https://shapebit.software/docs/) architecture disagree,
the demo decides.

The session starts Hyprland through [UWSM](https://github.com/Vladimir-csp/uwsm),
which runs the session's systemd units (`graphical-session.target` and the
applications that start with every session, XDG autostart), with the
configuration in `compositor/`, which starts the shell in `shell/`.

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
launchers, and the wallpaper (the backends in `portal/portal` and
`portal/share-picker` hand it their questions). The portal backend also
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
half size, two to a slot (Settings > Shell, over `shell/services/bars.js`). With the pointer, windows move only on the maps: drag a window's cell onto
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

From the monorepo root, create and enter the shared Fedora development
environment (see the [setup instructions](https://github.com/shapebit-software/os#development)).
Then run the checks:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
cd desktop
make check   # verify the compositor configuration and lint the shell
make run     # run the desktop in a window, inside the current Wayland session
make help    # all targets
```

`make run` needs a Wayland session and a GPU on the host. The desktop then
works on the host's real devices: Apps lists the container's applications and,
through the shared home, the host's exported ones; the bar's panels change the
host's volume, Wi-Fi, and Bluetooth; captures go to the host's Pictures and
Videos. Only the power actions are held back: they log instead of suspending,
restarting, or shutting down the host.

The desktop has a session bus of its own (`dev/run`), so what runs inside
reaches its own notification server and portals, as in the image, from this
tree; not the host's. Apps there offers the **Portal Tester**
(`dev/portal-tester`), which asks each portal and logs the answer; a button's
name, as its tooltip shows, presses it at the start, such as
`dev/portal-tester open_files`. Neither is installed.

The connection agent (`session/connection-agent`) joins networks and pairs
devices on the host's NetworkManager and BlueZ for real. In development it
does not take over from the host's own agents, so a network asking for its
password again asks the host's desktop.

Welcome opens until it is finished or skipped (`welcomed` in
`~/.config/desktop/settings.json`), and Settings > Account opens it again.
Its **Installing** step, Settings > Apps, and Settings > Downloads go through
the queue (`downloads/downloads`), which runs its jobs with the host's
`systemd-run --user`: the browser and the apps install into the host
account's own Flatpak installation for real, and the browser becomes the
default. Its state is `~/.local/state/desktop/downloads.json`.

The shell starts the assistant (`assistant/assistant serve`) itself, on a
socket of its own. The container has neither its model server nor the speech
engine: `make dev-assistant` in the repository's root, on the host and after
`make image`, copies `llama-server` out of the image and installs sherpa-onnx
with pip, into `build/dev`. `make run` then starts the model's server with
the first request, and voice and dictation write speech down. The models are
extras as in the installed system, but the person's own here, in
`build/dev/extras`: Settings > Assistant downloads them for real, without an
administrator. Another model can be listed in
`~/.config/assistant/models.json`, for example
`{"id": "dev", "name": "Dev", "where": "online", "url": "http://127.0.0.1:8080/v1"}`.
The model reads pictures of the screen once its Screen understanding extra is
downloaded, from the next `make run`, which loads it. The assistant's actions
run the real commands, so they change the host. The host's desktop may keep
the Super key for itself, as GNOME does: pressed alone, Super then opens the
host's overview, its letting go never arrives here, and every key after it
counts as a shortcut until `make run` starts again. So here the right Ctrl
key stands in for Super alone: a tap opens the assistant, and held, it
listens. The assistant's button does the same.

Settings > Apps (`apps/app-catalog`, `apps/app-remove`) lists and changes
the same installation, through Flatpak on the host; without one, it says so.

The lock screen checks the password of the container's account, which
distrobox leaves empty, so any password unlocks it. Set one with
`sudo passwd $USER` in the container to try it for real.

`make install DESTDIR=<directory>` installs the files as the image does.

Each folder of `shell/` is a QML module, `qs.<folder>`. Every QML file must be
listed in its folder's `qmldir`, and a file imports the other folders it uses.

## Layout

| Path          | Purpose                                                                                                                    |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `compositor/` | The Hyprland configuration (Lua): look, key bindings, layouts and resizing (`layouts.lua`), workspaces (`workspaces.lua`). |
| `shell/`      | The Quickshell configuration (QML): `services/` (singletons that hold state), `controls/`, `wallpaper/`, `bar/`, `windows/`, `settings/`, `lock/`, `capture/`, `notifications/`, `dialogs/`. |
| `session/`    | The session entry that the login screen starts, the connection agent, and the window button defaults.                    |
| `portal/`     | The session's portals: the shell's backend, the share picker, and their configuration.                                   |
| `apps/`       | The helpers of Welcome and Settings > Apps, and the timer that updates the apps.                                         |
| `assistant/`  | The assistant's service, its actions and skills, the model catalog, and the units that run it and `llama-server` on demand. |
| `downloads/`  | The one queue of downloads and installs, which Settings > Downloads shows, and the unit that resumes it at sign-in.     |
| `dictation/`  | Dictation: `hear` turns speech into words, for dictation and the assistant; `dictate` is the input method that delivers them. |
| `extras/`     | The extras (large optional downloads, such as models) with their hashes, and the helper that installs them.           |
| `packages`    | The packages the desktop runs on, each with its reason; the image installs them.                                         |
| `dev/`        | Development only: the session bus of `make run`, and the Portal Tester.                                                    |

## Not yet implemented

- The assistant reads no files' contents and no clipboard. `make run` needs
  sherpa-onnx and Parakeet in the development container to dictate
  (`DICTATION_PYTHON`, `DICTATION_PARAKEET`). The OS image has sherpa-onnx;
  Parakeet is an extra, downloaded from Welcome or Settings > Assistant
  (`extras/`).
- Settings has only what works: no first day of the week.
- Tabs cannot be dragged.
- Tile sizes last while the workspace keeps its layout, not across sessions.
