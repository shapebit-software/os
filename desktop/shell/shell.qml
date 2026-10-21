// The shell of ShapeBit Desktop: every surface that is not an application
// window: the wallpaper, the bar, the strip with Apps and the workspaces,
// and Settings.
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
    Variants {
        model: Quickshell.screens

        SettingsWindow {}
    }
}
