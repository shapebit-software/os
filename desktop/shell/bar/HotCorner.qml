// The quick actions in the screen's bottom right corner, when they open from
// a hot corner (Settings.quickActions "Hot corner"): the pointer in the
// corner fans out the buttons for the assistant, dictation (unless hidden
// in Settings > Shell), and capture, as
// in the demo. While recording, a red pill there shows the time; a click on
// it stops the recording. Dictation shows itself (DictationOverlay.qml). While
// the assistant listens or writes down what was said, a pill there shows it, as
// its button on a bar would (QuickButton.qml).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: corner

    required property ShellScreen modelData

    property bool fanned

    function act(panel: string, button: Item) {
        fanned = false;
        if (panel === "capture") {
            Capture.begin(modelData);
            return;
        }
        if (panel === "dictation") {
            Dictation.toggle();
            return;
        }
        // The assistant: what was open last, its bubbles here or its panel.
        const at = button.mapToItem(null, 0, 0);
        Assistant.tap(modelData.name, () => Shell.toggle(panel, modelData.name,
            Qt.rect(modelData.width - width + at.x, modelData.height - height + at.y, button.width, button.height),
            "Bottom", Theme.stripHeight + Theme.gap));
    }

    screen: modelData
    visible: Settings.quickActions === "Hot corner"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "corner"
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    implicitWidth: 190
    implicitHeight: 190
    color: "transparent"
    // The corner takes the pointer; fanned out, so do the buttons, and while
    // recording, the pill.
    mask: Region {
        x: corner.fanned ? 0 : corner.width - 14
        y: corner.fanned ? 0 : corner.height - 14
        width: corner.fanned ? corner.width : 14
        height: corner.fanned ? corner.height : 14

        Region { item: Capture.recording ? pill : null }
    }

    // The corner's mark.
    Rectangle {
        x: parent.width - 10
        y: parent.height - 10
        width: 20
        height: 20
        radius: 10
        color: Theme.sheen(0.4)
    }

    HoverHandler {
        onHoveredChanged: corner.fanned = hovered
    }

    // The fan: a quarter of a circle with the buttons on it.
    Item {
        anchors.fill: parent
        opacity: corner.fanned ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 140 } }

        Rectangle {
            x: parent.width - 170
            y: parent.height - 170
            width: 340
            height: 340
            radius: 170
            color: Theme.hud(0.6)
        }

        Repeater {
            model: [
                { panel: "assistant", right: 13, bottom: 96, strokes: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z" },
                ...(!Settings.hiddenItems.includes("dictation") ? [{ panel: "dictation", right: 65, bottom: 65, strokes: "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2" }] : []),
                { panel: "capture", right: 96, bottom: 13, strokes: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z" },
            ]

            Rectangle {
                id: button

                required property var modelData
                required property int index

                x: corner.width - modelData.right - width
                y: corner.height - modelData.bottom - height
                width: 46
                height: 46
                radius: 23
                color: Theme.sheen(buttonHover.hovered ? 0.2 : 0.1)
                scale: corner.fanned ? 1 : 0.4

                Behavior on scale { NumberAnimation { duration: 180 } }

                Icon {
                    anchors.centerIn: parent
                    color: Theme.textBright
                    strokes: button.modelData.strokes
                }
                TapHandler {
                    onTapped: corner.act(button.modelData.panel, button)
                }
                HoverHandler {
                    id: buttonHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // The assistant listens: what the microphone hears.
    Rectangle {
        visible: Assistant.voice !== "" && !corner.fanned
        x: corner.width - Theme.gap - width
        y: corner.height - Theme.gap - 14 - height - (pill.visible ? pill.height + 6 : 0)
        width: 46
        height: 32
        radius: 16
        color: Theme.accent

        DictationBars {
            anchors.centerIn: parent
            listening: Assistant.voice === "listening"
            writing: Assistant.voice === "writing"
            level: Assistant.level
        }
    }

    // The recording, over the corner.
    Rectangle {
        id: pill

        visible: Capture.recording && !corner.fanned
        x: corner.width - Theme.gap - width
        y: corner.height - Theme.gap - 14 - height
        width: time.width + 34
        height: 32
        radius: 16
        color: Theme.dangerFill

        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 2
            color: Theme.textOnAccent
        }
        Text {
            id: time
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: Capture.elapsed
            color: Theme.textOnAccent
            font { family: Theme.mono; pixelSize: 11; weight: Font.DemiBold }
        }
        TapHandler {
            onTapped: Capture.stop()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
