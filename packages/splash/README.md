# Splash

The boot splash, and its hand-off to the login screen: the package `shapebit-splash`.

[Plymouth](https://gitlab.freedesktop.org/plymouth/plymouth) shows the logo and
a spinner from the initramfs on, instead of boot messages
([30-splash.toml](system/30-splash.toml));
it also asks for the recovery key when the TPM cannot unlock. The theme
(`boot.plymouth`, `watermark.png`) is Fedora's spinner theme with the logo. Plymouth shows only messages when
the kernel console includes a serial port, as it does for development, so
`plymouth.ignore-serial-consoles` tells it to draw on the screen anyway.
Errors still reach the console; `Esc` shows the messages during boot.

Every step up to the desktop shares the splash's night color, `#1f1a3c`, so
none shows a black frame: the login screen and the installer take the screen
from Plymouth, which leaves its last picture until they draw
([sddm-splash.conf](system/sddm-splash.conf));
the login screen fades in from the color and back to it after signing in;
the text console, briefly shown between them, has it as its background; and
Hyprland paints it until the shell's wallpaper fades in.
