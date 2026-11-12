// A quick action's button on a bar (ShellItem.qml), shown with
// Settings.quickActions "Buttons": the assistant's, or the button to capture
// or to dictate. Each is an item of its own, and on the dock it can be half
// size, two to a slot (Shell.qml).
//
// While recording, the capture button is red with the recording's length,
// and a click on it stops the recording. While the screen is shared
// (SharePicker.qml), it is filled with the accent and shows a screen, and
// says with which applications. While dictating (Dictation.qml), the dictation
// button is filled with the accent and its icon says the state: sound bars that
// follow the voice while listening, a wave running through them while writing it
// down, red when something is wrong, and then briefly where the words went, a
// check or a clipboard, which pops in; a click stops, a right click discards, or
// with nothing under way, starts a dictation that only copies. It has no tooltip
// of its own, only what the person must know, such as a missing microphone. The assistant's button opens what was open
// last, its bubbles or its panel (Assistant.qml), and closes it; while either is open
// on its screen, the button is lit and its sparkle filled. Held, it listens until let
// go, as Super does; a right click starts voice mode, or ends it, as a double tap on
// Super does: its pill shows beside the button (VoicePill.qml). In voice mode the
// button stays filled, so the open microphone is never out of sight, and its icon
// tells the state: rings going out from a dot while it listens, bars that follow the
// voice while the person speaks, a turning arc while it thinks, and the sparkle with a dot while
// an action waits. It is filled with the accent and shows sound bars while the
// assistant listens, and its sparkle turns while the assistant works; a dot says an
// action waits for the person.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
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
    readonly property bool dictating: dictate && (Dictation.active || Dictation.result !== null)
    readonly property bool hearing: dictate && (Dictation.listening && !Dictation.quiet || Dictation.writing)
    readonly property bool wrong: dictate && (Dictation.state === "failed" || Dictation.notice.startsWith("No m") || Dictation.notice.startsWith("Mic"))

    readonly property string sparkle: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
    readonly property string frame: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
    readonly property string screen: "M2 2.5h12v8H2zM5.5 13.5h5M8 10.5v3M8 8.5v-4M6.25 6.25 8 4.5l1.75 1.75"

    tile: bar.dock
    // Voice mode's state (Assistant.voiceState), or "".
    readonly property string voiceState: assistant ? Assistant.voiceState : ""
    // Bars: held to talk, or speaking in voice mode.
    readonly property bool listening: assistant && Assistant.voice === "listening" && ["", "speaking"].includes(voiceState)
    readonly property bool working: assistant && !listening && voiceState === ""
        && (Assistant.voice === "writing" || Assistant.busy && !Assistant.attention)

    open: assistant && (Shell.isOpen("assistant", screenName) || Assistant.panelOn === (bar.modelData?.name ?? "-"))
    fill: red || wrong ? Theme.dangerFill : shared || dictating || listening || assistant && Assistant.conversing ? Theme.accent : "transparent"
    onHeld: {
        if (assistant)
            Assistant.listen();
    }
    onLetGo: {
        if (assistant)
            Assistant.endListening(true);
    }
    onClicked: {
        if (assistant)
            Assistant.tap(screenName, () => bar.open("assistant", button));
        else if (dictate)
            Dictation.toggle(false);
        else if (Capture.recording)
            Capture.stop();
        else
            Capture.begin(bar.modelData);
    }
    onRightClicked: {
        if (dictate)
            Dictation.secondary();
        else if (assistant)
            Assistant.toggleConversation(screenName, bar.place(button));
    }

    // Voice mode, started from the keyboard, shows its pill by this button.
    Connections {
        target: button.assistant ? Assistant : null

        function onVoiceAsked(screen: string) {
            if (screen === button.screenName && button.visible && !Assistant.voiceAt)
                Assistant.voiceAt = button.bar.place(button);
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
        hovered: button.visible && (button.assistant ? Assistant.notice !== "" : button.dictate && Dictation.telling
            || button.hovered && (button.red || button.shared))
        text: button.assistant ? Assistant.notice
            : button.red ? `Recording ${Capture.elapsed} · click to stop`
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
    // The assistant listens: what the microphone hears; in voice mode, flat
    // until the person speaks, so a noisy room doesn't look like speech.
    DictationBars {
        visible: button.listening
        size: button.half ? 12 : 16
        spacing: button.half ? 1 : 2
        listening: true
        writing: false
        level: Assistant.level
    }
    // Voice mode listens: a dot, with rings going out from it, as from a
    // pebble in water, one after the other.
    Item {
        id: ripple

        readonly property real size: button.half ? 14 : 18

        visible: button.voiceState === "listening"
        width: size
        height: size

        Rectangle {
            anchors.centerIn: parent
            width: ripple.size / 4
            height: width
            radius: width / 2
            color: Theme.textOnAccent
        }
        Repeater {
            model: 2

            Rectangle {
                id: ring

                required property int index

                anchors.centerIn: parent
                width: ripple.size
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Theme.textOnAccent
                border.width: 1.5
                scale: 0.3
                opacity: 0

                SequentialAnimation {
                    running: ripple.visible
                    loops: Animation.Infinite

                    PauseAnimation { duration: ring.index * 800 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; from: 0.3; to: 1; duration: 1600; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 1600; easing.type: Easing.InQuad }
                    }
                    PauseAnimation { duration: (1 - ring.index) * 800 }
                }
            }
        }
    }
    // Voice mode thinks: a turning arc.
    Icon {
        id: arc
        visible: button.voiceState === "thinking"
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

        visible: !button.assistant && !button.red && !button.hearing
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

        // The words show above this button, on the screen in use.
        function onActiveChanged() {
            if (Dictation.active && button.visible && button.screenName === Hyprland.focusedMonitor?.name)
                Dictation.at = button.bar.place(button);
        }
    }

    // The assistant's sparkle, which turns while it works, and its dot.
    Item {
        visible: button.assistant && !button.listening && ["", "waiting"].includes(button.voiceState)
        width: sparkle.width
        height: sparkle.height

        Icon {
            id: sparkle
            height: button.half ? 14 : button.tile ? 20 : 18
            color: Theme.textOnAccent
            strokes: button.sparkle
            fills: button.open ? button.sparkle : ""

            RotationAnimation on rotation {
                running: button.working
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1600
                onRunningChanged: if (!running) sparkle.rotation = 0
            }
            SequentialAnimation on opacity {
                running: button.working
                loops: Animation.Infinite
                onRunningChanged: if (!running) sparkle.opacity = 1
                NumberAnimation { to: 0.45; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
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
