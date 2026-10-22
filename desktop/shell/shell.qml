// The shell of ShapeBit Desktop: every surface that is not an application
// window: the wallpaper, the tabs of Tabs and Accordion, the handles that
// resize tiles, the system bar and the dock (Shell.qml) with their panels,
// the hot corner, the way out of full screen, Settings, and the lock screen.
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

        Resizer {}
    }
    Variants {
        model: Quickshell.screens

        ShellBar {
            kind: "system"
        }
    }
    Variants {
        model: Quickshell.screens

        ShellBar {
            kind: "dock"
        }
    }
    Variants {
        model: Quickshell.screens

        Panels {}
    }
    Variants {
        model: Quickshell.screens

        HotCorner {}
    }
    Variants {
        model: Quickshell.screens

        FullscreenExit {}
    }
    Variants {
        model: Quickshell.screens

        SettingsWindow {}
    }
}
