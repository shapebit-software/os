// The shell of ShapeBit Desktop: every surface that is not an application
// window: the wallpaper, the tabs of Tabs and Accordion, the handles that
// resize tiles, the system bar and the dock (Shell.qml) with their panels,
// the hot corner, the way out of full screen, Settings, the lock screen, and
// the question for an administrator's password, the capture overlay, which
// also picks what to share, and the file chooser, which a portal shows.
import Quickshell

ShellRoot {
    // hypridle runs from the start (Idle.qml) and locks through the lock
    // screen, so both start with the shell rather than when first used.
    readonly property string idle: Idle.config
    readonly property bool locked: Lock.locked
    // Copied text is kept from the start.
    readonly property string clipboard: Clipboard.path
    // The notification server starts with the shell, before anything sends.
    readonly property int notifications: Notifications.all.length
    // The polkit agent registers with the shell, before anything asks.
    readonly property bool authorizing: Authorization.asking
    // The portals listen from the start, for applications to ask.
    readonly property string portal: Portal.path

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
    Variants {
        model: Quickshell.screens

        AuthorizationPrompt {}
    }
    Variants {
        model: Quickshell.screens

        FileChooserDialog {}
    }
    Variants {
        model: Quickshell.screens

        CaptureOverlay {}
    }
    Variants {
        model: Quickshell.screens

        NotificationBanners {}
    }
}
