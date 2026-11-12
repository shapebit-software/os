// What dictation shows beyond its button, on the focused screen: the words while
// the person speaks, when the text field does not show them itself
// (dictation/dictate), above the button, or with no button, in the bottom right
// corner; and, only with no button to show the state, a pill there, so that an
// open microphone is never out of sight. The pointer passes through all but the
// pill, and it never takes the keyboard, so the application keeps its text field.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
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
    visible: (pill || Dictation.preview) && Hyprland.focusedMonitor?.name === modelData.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dictation"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: pillShape }

    // The words: all of them, the newest lines if there are many; small, light,
    // and with a soft shadow, so that they read on anything, with no card.
    Item {
        id: words

        readonly property var at: Dictation.at?.screen === overlay.modelData.name ? Dictation.at : null
        readonly property rect button: at?.rect ?? Qt.rect(0, 0, 0, 0)
        readonly property string edge: at?.edge ?? ""
        readonly property int lines: 4
        readonly property real depth: at?.depth ?? 0
        // Past the bar, toward the screen's middle, and lined up with the button.
        readonly property real across: edge === "Left" ? depth + 8
            : edge === "Right" ? overlay.width - depth - 8 - width
            : Math.max(16, Math.min(overlay.width - 16 - width,
                button.x + button.width / 2 > overlay.width / 2 ? button.x + button.width - width : button.x))
        readonly property real along: edge === "Top" ? depth + 8
            : edge === "Bottom" ? overlay.height - depth - 8 - height
            : Math.max(16, Math.min(overlay.height - 16 - height, button.y + button.height - height))
        readonly property bool rightAligned: at ? button.x + button.width / 2 > overlay.width / 2 : true

        visible: Dictation.preview
        x: at ? across : overlay.width - overlay.fromRight - width
        y: at ? along : overlay.height - overlay.fromBottom - (overlay.pill ? pillShape.height + 8 : 0) - height
        width: Math.min(360, overlay.width - 32)
        height: Math.min(said.implicitHeight, lines * metrics.lineSpacing)
        clip: true
        opacity: 0.9
        // A tight dark halo, as captions have, reads on white as on dark.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow(1)
            shadowOpacity: 1
            shadowBlur: 0.25
            shadowScale: 1.01
        }

        FontMetrics {
            id: metrics
            font: said.font
        }
        Text {
            id: said

            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            text: Dictation.words
            wrapMode: Text.Wrap
            horizontalAlignment: words.rightAligned ? Text.AlignRight : Text.AlignLeft
            color: Theme.textBright
            font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
            Accessible.role: Accessible.StatusBar
            Accessible.name: text
        }
    }

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
                visible: Dictation.listening || Dictation.writing
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
