# Login

The login screen, and the secrets its password unlocks: the package `shapebit-login`.

[SDDM](https://github.com/sddm/sddm) shows the login screen on the first
virtual terminal; its greeter runs in Hyprland, the desktop's compositor, with
its own configuration
([compositor.lua](compositor.lua)).
Weston, SDDM's usual compositor, shows it without a cursor. The theme, in
[theme](theme), draws
the screen: the date and time, the accessibility and power menus, and the
person who signs in with their password. It lists systemd-homed users, uses
the Instrument Sans font (SIL Open Font License, in
[font](../font/),
since Fedora has no package of it), and draws its backdrop itself.

Signing in starts the desktop session: Hyprland with the ShapeBit shell, run
by UWSM. The login screen offers no other session, since Hyprland's own
entries are removed; without one it says so. Consoles are on the other
virtual terminals (Ctrl+Alt+F3). The
installer medium masks `sddm.service`, because the installer takes the screen
there.

To change the theme, run it in a window on a machine with SDDM:

```bash
sddm-greeter-qt6 --test-mode --theme packages/login/theme
```
