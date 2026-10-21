// The shell of ShapeBit Desktop: every surface that is not an application
// window. For now, that is the wallpaper, the bar, and the strip
// with Apps and the workspaces.
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
    Variants {
        model: Quickshell.screens

        Strip {}
    }
}
