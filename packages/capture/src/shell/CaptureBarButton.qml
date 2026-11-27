// Capture's button on a bar, which the shell places by its name, "capture"
// (feature.qml, Features.qml): it opens the capture overlay (Capture.qml).
// While recording, it is red with the recording's length, and a click on it
// stops the recording; then, while Skip silence cuts the recording, it says so
// when hovered. While the screen is shared (SharePicker.qml), it is filled
// with the accent and shows a screen, and says with which applications.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

BarButton {
    id: button

    // The ShellBar, its half size, and its size, which the shell gives a
    // feature's item once made (ShellItem.qml).
    property var bar: null
    property bool half

    readonly property bool red: Capture.recording
    readonly property bool shared: SharePicker.sharing
    // Skip silence cutting the recording that ended.
    readonly property bool cutting: Capture.cutting

    readonly property string frame: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
    readonly property string screen: "M2 2.5h12v8H2zM5.5 13.5h5M8 10.5v3M8 8.5v-4M6.25 6.25 8 4.5l1.75 1.75"

    tile: bar?.dock ?? false
    fill: red ? Theme.dangerFill : shared ? Theme.accent : "transparent"
    onClicked: {
        if (Capture.recording)
            Capture.stop();
        else
            Capture.begin(bar.modelData);
    }

    // While recording, its length so far; as wide as the button, so the
    // button keeps its size.
    Text {
        visible: button.red
        width: button.size - 12
        horizontalAlignment: Text.AlignHCenter
        text: Capture.elapsed
        color: Theme.textOnAccent
        font { family: Theme.mono; pixelSize: button.half ? 9 : 11; weight: Font.DemiBold }
    }
    Tooltip {
        target: button
        edge: button.bar?.edge ?? "Bottom"
        hovered: button.visible && button.hovered && (button.red || button.shared || button.cutting)
        text: button.red ? `Recording ${Capture.elapsed} · click to stop`
            : button.cutting ? "Skipping the recording's silences"
            : SharePicker.viewers.length ? `Sharing the screen with ${SharePicker.viewers.join(", ")}`
            : "Sharing the screen"
    }
    Icon {
        visible: !button.red
        height: button.half ? 14 : 18
        color: Theme.textBright
        strokeWidth: 1.5
        strokes: button.shared ? button.screen : button.frame
    }
}
