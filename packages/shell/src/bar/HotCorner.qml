// The quick actions in the screen's bottom right corner, when they open from
// a hot corner (Settings.quickActions "Hot corner"): the pointer in the
// corner fans out the buttons of the quick actions on a quarter circle, by
// their order: the features' (Features.qml), such as the assistant's and
// capture's, and dictation's (unless hidden in Settings > Shell), as in the
// demo. While a feature records, a red pill there shows the time; a click on
// it stops the recording (Features.recording). Dictation shows itself
// (DictationOverlay.qml). While a feature listens or writes down what was
// said, a pill there shows it (Features.voice), as its button on a bar would.
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

    // The quick actions, by their order: the features', and dictation's.
    readonly property var actions: [
        ...Features.actions,
        ...(!Settings.hiddenItems.includes("dictation") ? [{ name: "dictation", order: 1, icon: "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2" }] : []),
    ].map((action, i) => [action.order ?? Infinity, i, action]).sort((a, b) => a[0] - b[0] || a[1] - b[1]).map(a => a[2])
    // Their places, from the corner, on the quarter circle, then up the edge.
    function place(i: int): var {
        return [{ right: 13, bottom: 96 }, { right: 65, bottom: 65 }, { right: 96, bottom: 13 }][i]
            ?? { right: 13, bottom: 152 + 56 * (i - 3) };
    }

    function act(action: var, button: Item) {
        fanned = false;
        if (action.name === "dictation") {
            Dictation.toggle(false);
            return;
        }
        // A feature's: on this screen, where the button is.
        const at = button.mapToItem(null, 0, 0);
        action.tap(modelData.name, Qt.rect(modelData.width - width + at.x, modelData.height - height + at.y,
            button.width, button.height));
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

        Region { item: Features.recording ? pill : null }
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
            model: corner.actions

            Rectangle {
                id: button

                required property var modelData
                required property int index

                x: corner.width - corner.place(index).right - width
                y: corner.height - corner.place(index).bottom - height
                width: 46
                height: 46
                radius: 23
                color: Theme.sheen(buttonHover.hovered ? 0.2 : 0.1)
                scale: corner.fanned ? 1 : 0.4

                Behavior on scale { NumberAnimation { duration: 180 } }

                Icon {
                    anchors.centerIn: parent
                    color: Theme.textBright
                    strokes: button.modelData.icon
                }
                TapHandler {
                    onTapped: corner.act(button.modelData, button)
                }
                HoverHandler {
                    id: buttonHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // A feature listens: what the microphone hears.
    Rectangle {
        visible: Features.voice !== null && !corner.fanned
        x: corner.width - Theme.gap - width
        y: corner.height - Theme.gap - 14 - height - (pill.visible ? pill.height + 6 : 0)
        width: 46
        height: 32
        radius: 16
        color: Theme.accent

        DictationBars {
            anchors.centerIn: parent
            listening: Features.voice?.listening ?? false
            writing: Features.voice?.writing ?? false
            level: Features.voice?.level ?? 0
        }
    }

    // The recording, over the corner.
    Rectangle {
        id: pill

        visible: Features.recording !== null && !corner.fanned
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
            text: Features.recording?.elapsed ?? ""
            color: Theme.textOnAccent
            font { family: Theme.mono; pixelSize: 11; weight: Font.DemiBold }
        }
        TapHandler {
            onTapped: Features.recording?.stop()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
