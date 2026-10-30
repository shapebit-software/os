// New notifications as banners in the top right corner of the focused
// screen, below the system bar when it is at the top, newest on top. Each
// goes after the application's time or a few seconds, and stays while the
// pointer is on it; critical ones stay until dismissed. Gone from here, they
// stay in the panel. They are above full-screen windows, but hidden while a
// panel is open.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: window

    required property ShellScreen modelData

    // Not over a panel open on the screen, which takes the attention.
    visible: Notifications.banners.length > 0
        && (Hyprland.focusedMonitor?.name ?? "") === (modelData?.name ?? "")
        && !(Shell.panel && Shell.panelScreen === modelData?.name)
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    // The space to the screen's edges is the window's, and takes no input,
    // so the bar beside it keeps its clicks.
    readonly property real top: Theme.gap + (Settings.systemBar === "Top" ? Theme.barHeight : 0)
    readonly property real right: Theme.gap + (Settings.systemBar === "Right" ? Theme.barHeight : 0)
    implicitWidth: 360 + right
    implicitHeight: top + Math.max(1, column.height)
    mask: Region { item: column }

    Column {
        id: column
        y: window.top
        width: 360
        spacing: 8

        Repeater {
            model: Notifications.banners

            NotificationCard {
                id: banner

                required property Notification modelData

                width: column.width
                notification: modelData
                banner: true

                HoverHandler {
                    id: rest
                }
                Timer {
                    // The application's time, in milliseconds; held within reason.
                    interval: Math.max(2000, Math.min(30000, banner.modelData.expireTimeout > 0
                        ? banner.modelData.expireTimeout : Notifications.bannerTime))
                    running: !banner.critical && !rest.hovered
                    onTriggered: Notifications.hideBanner(banner.modelData)
                }
            }
        }
    }
}
