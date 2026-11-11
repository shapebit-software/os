// The applications running in the background that show an icon for it
// (StatusNotifierItem, which Quickshell watches for): their icons stand on a
// bar (TrayIcons.qml), side by side or stacked, as Settings says, and each
// one's menu opens as a panel (TrayMenu.qml).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "tray.js" as Logic

Singleton {
    // The icons to show, in the order their applications started.
    readonly property var items: Logic.shown(SystemTray.items.values, Status.Passive)
    // Whether the icons overlap until the pointer is on them.
    readonly property bool stacked: Settings.trayIcons === "Stacked"
    // The application whose menu the "tray" panel shows.
    property SystemTrayItem menuOf

    function needsAttention(item: SystemTrayItem): bool {
        return item.status === Status.NeedsAttention;
    }
}
