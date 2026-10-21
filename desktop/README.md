# ShapeBit Desktop

The desktop of ShapeBit OS: [Hyprland](https://hypr.land) as the compositor
and [Quickshell](https://quickshell.org) as the shell, following the
[demo](https://shapebit.software/demo/). Where the demo and the
[Desktop Environment](https://shapebit.software/docs/) architecture disagree,
the demo decides.

The session starts Hyprland with the configuration in `compositor/`, which
starts the shell in `shell/`. So far the shell draws the wallpaper, the bar,
the strip with Apps and the workspaces, and Settings. Settings are kept in
`~/.config/desktop/settings.json`; the shell applies them to itself and to the
compositor.

## Development

Create and enter the Fedora development environment, then run the checks:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter desktop
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
`make install DESTDIR=<directory>` installs the files as the image does.

Every QML file in `shell/` must be listed in `shell/qmldir`; Quickshell
ignores the others.

## Layout

| Path          | Purpose                                                                       |
| ------------- | ----------------------------------------------------------------------------- |
| `compositor/` | The Hyprland configuration (Lua): look, key bindings, layouts (`layouts.lua`). |
| `shell/`      | The Quickshell configuration (QML): every shell surface.                      |
| `session/`    | The session entry that the login screen starts.                               |

## Not yet implemented

- The session in the OS image; the image repository does not install the
  desktop yet.
- Everything in the demo but the wallpaper, the tile look, the bar and its
  panels, the strip, Apps, the layouts, quick actions with capture, Settings,
  and two key bindings (Alt+Q closes a window, Alt+F maximizes it): Overview,
  the lock screen, and the assistant.
- Settings has only what works: no password, automatic lock, or fingerprint
  (they come with the lock screen), no light theme, no night light, no VPN, no
  alert sounds, and no Assistant section. Values such as the resolution
  cannot be changed yet.
- Quick actions have no Dictate, and their button does not open the
  assistant; both come with the assistant. A click keeps the actions shown.
- The account panel has no Lock and no Settings, which come with the lock
  screen and Settings. The bar shows keyboard layout codes (US), where the
  demo shows language codes (EN).
- The strip has no dragging and no workspace menu; Apps has no dragging to a
  workspace and no page arrows.
- Layouts have no tab bar in Tabs, no resizing, and no moving windows between
  cells.
  There are always five workspaces; adding, removing, and renaming them comes
  with Overview.
