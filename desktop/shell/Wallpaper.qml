// The wallpaper of one screen, below every window. While the workspace on the
// screen has no windows, a note in the middle says so; a click on it opens
// Apps, beside the dock.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: wallpaper

    required property ShellScreen modelData

    readonly property HyprlandWorkspace workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null

    screen: modelData
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    Backdrop { anchors.fill: parent }

    Rectangle {
        id: note

        visible: wallpaper.workspace !== null && wallpaper.workspace.toplevels.values.length === 0
        anchors.centerIn: parent
        width: column.width + 40
        height: column.height + 28
        radius: Theme.rounded ? 9 : 0
        color: Qt.rgba(0.09, 0.08, 0.15, noteHover.hovered ? 0.7 : 0.55)

        Column {
            id: column

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing open here"
                color: "#f5f6f8"
                font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open Apps to add a window"
                color: "#dcdfe3"
                font { family: Theme.mono; pixelSize: 10 }
            }
        }

        TapHandler {
            onTapped: {
                const edge = Settings.dock;
                Shell.toggle("apps", wallpaper.modelData.name,
                    Qt.rect(note.x, note.y, note.width, note.height), edge, Theme.stripHeight + Theme.gap);
            }
        }
        HoverHandler {
            id: noteHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
