# ShapeBit Desktop

The desktop of ShapeBit OS: [Hyprland](https://hypr.land) as the compositor
and [Quickshell](https://quickshell.org) as the shell, following the
[demo](https://shapebit.software/demo/). Where the demo and the
[Desktop Environment](https://shapebit.software/docs/) architecture disagree,
the demo decides.

The session starts Hyprland with the configuration in `compositor/`, which
starts the shell in `shell/`. So far the shell draws the wallpaper and the
bar.

## Development

Create and enter the Fedora development environment, then run the checks:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter desktop
make check   # verify the compositor configuration and lint the shell
make run     # run the desktop in a window, inside the current Wayland session
make help    # all targets
```

`make run` needs a Wayland session and a GPU on the host. To open a window
in it, run `WAYLAND_DISPLAY=wayland-1 foot` in a second shell in the
container (`ls $XDG_RUNTIME_DIR` shows the socket if `wayland-1` is taken).
`make install DESTDIR=<directory>` installs the files as the image does.

## Layout

| Path          | Purpose                                                       |
| ------------- | ------------------------------------------------------------- |
| `compositor/` | The Hyprland configuration (Lua): look, layouts, key bindings. |
| `shell/`      | The Quickshell configuration (QML): every shell surface.      |
| `session/`    | The session entry that the login screen starts.               |

## Not yet implemented

- The session in the OS image; the image repository does not install the
  desktop yet.
- Everything in the demo but the wallpaper, the tile look, the bar, and two
  key bindings (Alt+Q closes a window, Alt+F maximizes it): the bar's panels
  and quick actions, workspaces, layouts, Apps, Overview, Settings, and the
  assistant. The bar's buttons do nothing yet, and its language code comes
  from the locale, not the keyboard layout.
