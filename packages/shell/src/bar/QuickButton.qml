// A quick action's button on a bar (ShellItem.qml), shown with
// Settings.quickActions "Buttons": the button to capture or to dictate; a
// feature's, such as the assistant's, is its own (Features.qml). Each is an
// item of its own, and on the dock it can be half size, two to a slot
// (Shell.qml).
//
// While recording, the capture button is red with the recording's length,
// and a click on it stops the recording; then, while Skip silence cuts the
// recording, it says so when hovered. While the screen is shared
// (SharePicker.qml), it is filled with the accent and shows a screen, and
// says with which applications. While dictating (Dictation.qml), the dictation
// button is filled with the accent and its icon says the state: sound bars that
// follow the voice while listening, a turning arc while it writes the words down,
// red when something is wrong, and then briefly where the words went, a
// check or a clipboard, which pops in; a click stops, a right click discards, or
// with nothing under way, starts a dictation that only copies. It has no tooltip
// of its own, only what the person must know, such as a missing microphone.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

BarButton {
    id: button

    // The ShellBar; qmllint does not take a ShellBar for itself inside
    // ShellBar.qml, where items are made.
    required property var bar
    // "capture" or "dictation".
    required property string kind
    property bool half

    readonly property string screenName: bar.modelData?.name ?? ""
    readonly property bool dictate: kind === "dictation"
    readonly property bool red: kind === "capture" && Capture.recording
    readonly property bool shared: kind === "capture" && SharePicker.sharing
    // Skip silence cutting the recording that ended.
    readonly property bool cutting: kind === "capture" && Capture.cutting
    readonly property bool dictating: dictate && (Dictation.active || Dictation.result !== null)
    readonly property bool hearing: dictate && Dictation.listening && !Dictation.quiet
    readonly property bool wrong: dictate && (Dictation.state === "failed" || Dictation.notice.startsWith("No m") || Dictation.notice.startsWith("Mic"))

    readonly property string frame: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
    readonly property string screen: "M2 2.5h12v8H2zM5.5 13.5h5M8 10.5v3M8 8.5v-4M6.25 6.25 8 4.5l1.75 1.75"

    tile: bar.dock
    fill: red || wrong ? Theme.dangerFill : shared || dictating ? Theme.accent : "transparent"
    onClicked: {
        if (dictate)
            Dictation.toggle(false);
        else if (Capture.recording)
            Capture.stop();
        else
            Capture.begin(bar.modelData);
    }
    onRightClicked: {
        if (dictate)
            Dictation.secondary();
    }

    // Dictation's Tidy up shows by this button (TidyPill.qml).
    Connections {
        target: button.dictate ? Dictation : null

        function onPillAsked(screen: string) {
            if (screen === button.screenName && button.visible && !Dictation.pillAt)
                Dictation.pillAt = button.bar.place(button);
        }
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
        hovered: button.visible && (button.dictate && Dictation.telling
            || button.hovered && (button.red || button.shared || button.cutting))
        text: button.red ? `Recording ${Capture.elapsed} · click to stop`
            : button.cutting ? "Skipping the recording's silences"
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
    // Dictation writes the words down: a turning arc.
    Icon {
        id: arc
        visible: button.dictate && Dictation.writing
        height: button.half ? 14 : 18
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
    Icon {
        id: icon

        visible: !button.red && !button.hearing && !(button.dictate && Dictation.writing)
        height: button.half ? 14 : 18
        color: Theme.textBright
        strokeWidth: 1.5
        strokes: button.dictate ? Dictation.icon : button.shared ? button.screen : button.frame
    }

    // Where the dictated words went pops in.
    NumberAnimation {
        id: pop

        target: icon
        property: "scale"
        from: 0.4
        to: 1
        duration: 260
        easing.type: Easing.OutBack
    }
    Connections {
        target: button.dictate ? Dictation : null

        function onResultChanged() {
            if (Dictation.result)
                pop.restart();
        }
    }
}
