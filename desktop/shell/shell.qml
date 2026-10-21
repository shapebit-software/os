// The shell of ShapeBit Desktop: every surface that is not an application
// window. For now, that is the wallpaper and the bar.
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
