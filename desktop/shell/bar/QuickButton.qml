// A quick action's button on a bar (ShellItem.qml), shown with
// Settings.quickActions "Buttons": the assistant's, or the button to capture
// or to dictate. Each is an item of its own, and on the dock it can be half
// size, two to a slot (Shell.qml).
//
// While recording, the capture button is red with the recording's length,
// and a click on it stops the recording. While the screen is shared
// (SharePicker.qml), it is filled with the accent and shows a screen, and
// says with which applications. While dictating (Dictation.qml), the dictation
// button is filled with the accent and its icon says the state: sound bars while
// listening, a pencil while writing it down, lines while the text waits, red when
// something is wrong; a click stops, a right click discards, and with nothing
// under way, brings back the last dictation. The assistant's button opens its command line
// (AssistantPanel.qml); it is lit while the line or the sidebar is open on its screen, its
// sparkle breathes while the assistant works, and a dot says an action waits for the person.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

BarButton {
    id: button

    // The ShellBar; qmllint does not take a ShellBar for itself inside
    // ShellBar.qml, where items are made.
    required property var bar
    // "assistant", "capture", or "dictation".
    required property string kind
    property bool half

    readonly property string screenName: bar.modelData?.name ?? ""
    readonly property bool assistant: kind === "assistant"
    readonly property bool dictate: kind === "dictation"
    readonly property bool red: kind === "capture" && Capture.recording
    readonly property bool shared: kind === "capture" && SharePicker.sharing
    readonly property bool dictating: dictate && (Dictation.listening || Dictation.writing || Dictation.waiting)
    readonly property bool hearing: dictate && Dictation.listening && !Dictation.quiet
    readonly property bool wrong: dictate && (Dictation.state === "failed" || Dictation.notice.startsWith("No m") || Dictation.notice.startsWith("Mic"))

    readonly property string sparkle: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
    readonly property string frame: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
    readonly property string screen: "M2 2.5h12v8H2zM5.5 13.5h5M8 10.5v3M8 8.5v-4M6.25 6.25 8 4.5l1.75 1.75"

    tile: bar.dock
    open: assistant && (Shell.isOpen("assistant", screenName) || Assistant.sidebarOn === (bar.modelData?.name ?? "-"))
    fill: red || wrong ? Theme.dangerFill : shared || dictating ? Theme.accent : "transparent"
    onClicked: {
        if (assistant)
            bar.open("assistant", button);
        else if (dictate)
            Dictation.toggle();
        else if (Capture.recording)
            Capture.stop();
        else
            Capture.begin(bar.modelData);
    }
    onRightClicked: {
        if (dictate)
            Dictation.secondary();
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
        edge: button.bar.edge
        hovered: button.visible && !button.assistant && (button.dictate && Dictation.telling
            || button.hovered && (button.red || button.shared || button.dictate))
        text: button.red ? `Recording ${Capture.elapsed} · click to stop`
            : button.dictate ? Dictation.status
            : SharePicker.viewers.length ? `Sharing the screen with ${SharePicker.viewers.join(", ")}`
            : "Sharing the screen"
    }
    DictationBars {
        visible: button.hearing
        size: button.half ? 12 : 16
        // Narrow enough on a half-size button that it keeps its size.
        spacing: button.half ? 1 : 2
    }
    Icon {
        visible: !button.assistant && !button.red && !button.hearing
        height: button.half ? 14 : 18
        color: Theme.textBright
        strokeWidth: 1.5
        strokes: button.dictate ? Dictation.icon : button.shared ? button.screen : button.frame
    }

    // The assistant's sparkle, and its dot.
    Item {
        visible: button.assistant
        width: sparkle.width
        height: sparkle.height

        Icon {
            id: sparkle
            height: button.half ? 14 : button.tile ? 20 : 18
            color: Theme.textOnAccent
            strokes: button.sparkle

            SequentialAnimation on opacity {
                running: button.assistant && Assistant.busy && !Assistant.attention
                loops: Animation.Infinite
                onRunningChanged: if (!running) sparkle.opacity = 1
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            visible: Assistant.attention
            anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -2 }
            width: 7
            height: 7
            radius: 3.5
            color: Theme.accent
            border.color: Theme.textOnAccent
        }
    }
}
