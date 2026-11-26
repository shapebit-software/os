// A pill by a quick action's button (QuickButton.qml): off its bar, as a panel
// opens (Popout.qml), in the popovers' glass, with an arrow to the button; with
// no button on the bars, in the bottom right corner. It takes no keyboard, so
// the application keeps it. The assistant's (VoicePill.qml) and dictation's
// Tidy up (TidyPill.qml) are such pills.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: pill

    required property ShellScreen modelData
    // Where: { screen, rect, edge, depth }, as the bar tells it of the button
    // (ShellBar.place), or { screen, rect: null } for the corner.
    property var at: null
    property bool shown
    property string name
    readonly property bool hovered: hover.hovered
    default property alias content: frame.content
    readonly property real margin: Theme.gap

    screen: modelData
    visible: shown && (at?.screen ?? "") === modelData.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: name
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: frame }

    PopoverFrame {
        id: frame

        readonly property bool placed: pill.at?.rect !== undefined && pill.at?.rect !== null
        readonly property rect anchor: placed ? pill.at.rect : Qt.rect(0, 0, 0, 0)
        readonly property string edge: placed ? pill.at.edge : ""
        readonly property real depth: placed ? pill.at.depth : 0
        // Clear of the dock in the corner.
        readonly property real fromBottom: 14 + (Settings.dock === "Bottom" ? Theme.stripHeight + Theme.gap : 0)

        function clamp(at: real, size: real, length: real): real {
            return Math.max(pill.margin, Math.min(length - pill.margin - size, at - size / 2));
        }

        x: edge === "Left" ? depth + pill.margin
            : edge === "Right" ? pill.width - depth - pill.margin - width
            : edge === "" ? pill.width - width - pill.margin - 14
            : clamp(anchor.x + anchor.width / 2, width, pill.width)
        y: edge === "Top" ? depth + pill.margin
            : edge === "Bottom" ? pill.height - depth - pill.margin - height
            : edge === "" ? pill.height - height - pill.margin - fromBottom
            : clamp(anchor.y + anchor.height / 2, height, pill.height)
        padding: 10
        opacity: pill.visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler {
            id: hover
        }
    }
    // The arrow to the button, as a popover has.
    Item {
        readonly property string edge: frame.edge
        readonly property real centerX: edge === "Left" ? frame.x - 3.5
            : edge === "Right" ? frame.x + frame.width + 3.5
            : Math.max(frame.x + 12, Math.min(frame.x + frame.width - 12, frame.anchor.x + frame.anchor.width / 2))
        readonly property real centerY: edge === "Top" ? frame.y - 3.5
            : edge === "Bottom" ? frame.y + frame.height + 3.5
            : Math.max(frame.y + 12, Math.min(frame.y + frame.height - 12, frame.anchor.y + frame.anchor.height / 2))

        visible: frame.placed
        opacity: frame.opacity
        x: centerX - width / 2
        y: centerY - height / 2
        width: 18
        height: 9
        rotation: ({ "Bottom": 0, "Top": 180, "Left": 90, "Right": -90 })[edge] ?? 0
        clip: true

        Rectangle {
            x: 9 - width / 2
            y: -width / 2
            width: 12.7
            height: 12.7
            rotation: 45
            color: parent.edge === "Top" ? Theme.popoverTop : Theme.popoverBottom
            border.color: Theme.popoverRing
        }
    }
}
