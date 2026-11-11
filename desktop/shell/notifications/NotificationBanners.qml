// New notifications as banners on the focused screen, nearest the bell
// (Notifications.corner): at the top or the bottom, on a side or in the
// middle, clear of the bars, newest nearest the edge. At most a few show; the rest are counted below them, and a click
// there opens the panel. Each goes after the application's time or a few
// seconds, and stays while the pointer is on it; critical ones stay until
// dismissed. Gone from here, they stay in the panel. They are above
// full-screen windows, but hidden while a panel is open.
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

    readonly property bool atTop: Notifications.corner.top
    readonly property bool atLeft: Notifications.corner.side === "left"
    readonly property bool atRight: Notifications.corner.side === "right"

    // How far a bar on an edge reaches into the screen.
    function bar(edge: string): real {
        return Settings.systemBar === edge ? Theme.barHeight
            : Settings.dock === edge ? Theme.stripHeight + Theme.gap : 0;
    }

    // Not over a panel open on the screen, which takes the attention.
    visible: Notifications.banners.length > 0
        && (Hyprland.focusedMonitor?.name ?? "") === (modelData?.name ?? "")
        && !(Shell.panel && Shell.panelScreen === modelData?.name)
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: atTop; bottom: !atTop; left: atLeft; right: atRight }
    // The space to the screen's edges is the window's, and takes no input,
    // so the bars beside it keep their clicks.
    readonly property real across: Theme.gap + bar(atTop ? "Top" : "Bottom")
    readonly property real along: atLeft ? Theme.gap + bar("Left") : atRight ? Theme.gap + bar("Right") : 0
    implicitWidth: 360 + along
    implicitHeight: across + Math.max(1, column.height)
    mask: Region { item: column }

    Column {
        id: column
        x: window.atLeft ? window.along : 0
        y: window.atTop ? window.across : 0
        width: 360
        spacing: 8

        // From the edge: down from the top, up from the bottom.
        Repeater {
            model: window.atTop ? Notifications.shownBanners : [...Notifications.shownBanners].reverse()

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

        // The rest, counted.
        Rectangle {
            visible: Notifications.moreBanners > 0
            width: column.width
            height: 28
            color: Theme.popoverTop
            border.color: Theme.popoverRing

            Text {
                anchors.centerIn: parent
                text: `+${Notifications.moreBanners} more`
                color: Theme.inkSoft
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            TapHandler {
                onTapped: Shell.request("notifications", window.modelData?.name ?? "")
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
