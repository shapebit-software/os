// Dictation's pill, in the bottom right corner of the focused screen, only with
// no button to show the state (Settings > Shell, or the hot corner), so that an
// open microphone is never out of sight. It never takes the keyboard, so the
// application keeps its text field.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: overlay

    required property ShellScreen modelData

    readonly property bool noButton: Settings.quickActions === "Hot corner"
        || Settings.hiddenItems.includes("dictation")
    readonly property bool pill: noButton && (Dictation.active || Dictation.notice !== "" || Dictation.state === "failed"
        || Dictation.result !== null)
    // Clear of the dock, and of the hot corner's recording pill.
    readonly property int fromRight: Theme.gap + (Capture.recording && Settings.quickActions === "Hot corner" ? 110 : 0)
    readonly property int fromBottom: Theme.gap + 14 + (Settings.dock === "Bottom" ? Theme.stripHeight + Theme.gap : 0)

    screen: modelData
    visible: pill && Hyprland.focusedMonitor?.name === modelData.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    implicitWidth: pillShape.width + fromRight
    implicitHeight: pillShape.height + fromBottom
    color: "transparent"
    mask: Region { item: pillShape }

    // The pill.
    Rectangle {
        id: pillShape

        visible: overlay.pill
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: overlay.fromRight; bottomMargin: overlay.fromBottom }
        width: pillRow.width + 24
        height: 32
        radius: 16
        color: Dictation.state === "failed" ? Theme.dangerFill : Theme.accent
        Accessible.role: Accessible.StatusBar
        Accessible.name: status.text

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: 9

            DictationBars {
                visible: Dictation.listening
            }
            // Writing the words down: a turning arc, as on the button.
            Icon {
                id: arc

                visible: Dictation.writing
                implicitHeight: 14
                color: Theme.textOnAccent
                strokeWidth: 1.8
                strokes: "M8 2.5a5.5 5.5 0 1 1-5.5 5.5"

                RotationAnimation on rotation {
                    running: arc.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }
            Text {
                id: status
                text: Dictation.status
                color: Theme.textOnAccent
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
        }
        TapHandler {
            onTapped: Dictation.toggle(false)
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: Dictation.secondary()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
