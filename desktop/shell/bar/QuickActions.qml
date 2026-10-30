// The quick actions on a bar (Settings.quickActions "Buttons"): the
// assistant's button, and beside it the buttons to capture and to dictate.
// On the dock, the assistant's is a large glass tile with the other two
// stacked small beside it; on the system bar, all three are plain buttons.
// While recording, the capture button is red with the recording's length,
// and a click on it stops the recording. While the screen is shared
// (SharePicker.qml), it is filled with the accent and shows a screen, and
// says with which applications. The assistant and
// dictation are still to come: their buttons say so (AssistantPanel.qml).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.controls
import qs.services

GridLayout {
    id: actions

    required property ShellBar bar

    readonly property bool tile: bar.dock
    // The small buttons, across the bar from the large one on the dock.
    readonly property int small: tile ? (bar.size - 4) / 2 : bar.size

    readonly property string sparkle: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
    readonly property string frame: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
    readonly property string screen: "M2 2.5h12v8H2zM5.5 13.5h5M8 10.5v3M8 8.5v-4M6.25 6.25 8 4.5l1.75 1.75"
    readonly property string wave: "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2"

    function capture(button: Item) {
        if (Capture.recording)
            Capture.stop();
        else
            Capture.begin(bar.modelData);
    }

    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 4
    columnSpacing: 4

    // A small button: a glass tile on the dock, a plain one on the system bar.
    component Small: BarButton {
        id: small

        property string strokes
        property bool red
        property bool shared

        tile: actions.tile
        size: actions.small
        fill: red ? "#d23a3a" : shared ? Theme.accent : "transparent"

        // While recording, its length so far; as wide as the button, so the
        // button keeps its size.
        Text {
            visible: small.red
            width: actions.small - 12
            horizontalAlignment: Text.AlignHCenter
            text: Capture.elapsed
            color: "#fbfcfd"
            font { family: Theme.mono; pixelSize: actions.tile ? 9 : 11; weight: Font.DemiBold }
        }
        Tooltip {
            target: small
            edge: actions.bar.edge
            hovered: small.hovered && (small.red || small.shared)
            text: small.red ? `Recording ${Capture.elapsed} · click to stop`
                : SharePicker.viewers.length ? `Sharing the screen with ${SharePicker.viewers.join(", ")}`
                : "Sharing the screen"
        }
        Icon {
            visible: !small.red
            height: actions.tile ? 14 : 18
            color: "#f6f7f9"
            strokeWidth: 1.5
            strokes: small.shared ? actions.screen : small.strokes
        }
    }

    // On the dock, the small buttons share the bar's depth.
    GridLayout {
        visible: actions.tile
        flow: actions.bar.vertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rowSpacing: 4
        columnSpacing: 4

        Small {
            id: captureTile
            strokes: actions.frame
            red: Capture.recording
            shared: SharePicker.sharing
            onClicked: actions.capture(captureTile)
        }
        Small {
            id: dictateTile
            strokes: actions.wave
            onClicked: actions.bar.open("assistant", dictateTile)
        }
    }
    Small {
        id: captureButton
        visible: !actions.tile
        strokes: actions.frame
        red: Capture.recording
        shared: SharePicker.sharing
        onClicked: actions.capture(captureButton)
    }
    Small {
        id: dictateButton
        visible: !actions.tile
        strokes: actions.wave
        onClicked: actions.bar.open("assistant", dictateButton)
    }

    // The assistant's button.
    BarButton {
        id: assistant

        tile: actions.tile
        size: actions.bar.size
        open: Shell.isOpen("assistant", actions.bar.modelData?.name ?? "")
        onClicked: actions.bar.open("assistant", assistant)

        Icon {
            height: actions.tile ? 20 : 18
            color: "#fbfcfd"
            strokes: actions.sparkle
        }
    }
}
