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
notifications (banners, and a panel with Do Not Disturb), the display's
brightness, and the battery with the power profile, these two only where the
computer has them. The shell is also the session's polkit agent, which asks
for an administrator's password, its notification server, and, through the
portals, what applications ask: the file chooser, screenshots in the capture
overlay, and the share picker (the backends in `session/portal` and
`session/share-picker` hand it their questions). Captures from the quick
actions open the same overlay, with a panel of two rows: a selection, a
window, or the screen; and a timer, a switch between a screenshot and a
recording whose knob is the capture button, and editing; screenshots are saved at once, or, with editing, first open for
markup. It runs
hypridle, which locks the screen and turns it off after the idle times in
Settings and locks it before the computer sleeps, and clipman, which keeps
copied text after the application it came from closes. Settings are kept in
`~/.config/desktop/settings.json`; the shell applies them to itself and to the
compositor.

Each bar can sit on any edge, and its items can move between the bars' zones
or off the bars, hidden, all but the system menu (Settings > Shell). Windows move only on the maps: drag a window's cell onto
another cell or map; double-click it for full screen (Alt+F), which covers
the bars and ends from the button in the top right corner; right-click it to
close it (Alt+Q).

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

The lock screen checks the password of the container's account, which
distrobox leaves empty, so any password unlocks it. Set one with
`sudo passwd $USER` in the container to try it for real.

`make install DESTDIR=<directory>` installs the files as the image does.

Every QML file in `shell/` must be listed in `shell/qmldir`; Quickshell
ignores the others.

## Layout

| Path          | Purpose                                                                                                                    |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `compositor/` | The Hyprland configuration (Lua): look, key bindings, layouts and resizing (`layouts.lua`), workspaces (`workspaces.lua`). |
| `shell/`      | The Quickshell configuration (QML): every shell surface.                                                                   |
| `session/`    | The session entry that the login screen starts, and the session's portals.                                                 |

## Not yet implemented

- The assistant and dictation: their buttons, the Settings section, and the
  hot corner say they are coming.
- Settings has only what works: no password change, no system language, or
  first day of the week.
- Tabs cannot be dragged.
- Tile sizes last while the workspace keeps its layout, not across sessions.
