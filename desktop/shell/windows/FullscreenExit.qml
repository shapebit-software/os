// The way out of full screen on one screen: while a window covers it, the
// pointer in the top right corner shows a button that ends full screen.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: corner

    required property ShellScreen modelData

    readonly property HyprlandWorkspace workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
    readonly property bool shown: hover.hovered

    screen: modelData
    visible: workspace?.hasFullscreen ?? false
    // Above the full screen window, which covers the other layers.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "fullscreen"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    implicitWidth: 76
    implicitHeight: 76
    color: "transparent"
    // A thin strip in the corner takes the pointer; once it is there, the
    // whole corner does.
    mask: Region {
        x: corner.shown ? 0 : corner.width - 10
        width: corner.shown ? corner.width : 10
        height: corner.shown ? corner.height : 10
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        width: 30
        height: 30
        radius: 15
        color: buttonHover.hovered ? "#d5403a" : Qt.rgba(0.14, 0.13, 0.17, 0.72)
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: corner.shown ? 1 : 0
        transform: Translate { y: corner.shown ? 0 : -6 }

        Behavior on opacity { NumberAnimation { duration: 140 } }

        Icon {
            anchors.centerIn: parent
            height: 12
            gridWidth: 12
            gridHeight: 12
            strokeWidth: 1.5
            capStyle: ShapePath.SquareCap
            color: "#f6f7f9"
            strokes: "M2 2l8 8M10 2l-8 8"
        }

        TapHandler {
            onTapped: Compositor.exitFullscreen(corner.workspace.id)
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
