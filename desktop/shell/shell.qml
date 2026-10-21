// The shell of ShapeBit Desktop: every surface that is not an application
// window: the wallpaper, the tabs of Tabs and Accordion, the bar, the strip
// with Apps and the workspaces, Settings, and the lock screen.
import Quickshell

ShellRoot {
    // The lock screen locks by itself after idle time, so it starts with the
    // shell rather than when first used.
    readonly property bool locked: Lock.locked

    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens

        WindowTabs {}
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
