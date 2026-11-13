// A quick action's button on a bar (ShellItem.qml), shown with
// Settings.quickActions "Buttons": the assistant's, or the button to capture
// or to dictate. Each is an item of its own, and on the dock it can be half
// size, two to a slot (Shell.qml).
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
// of its own, only what the person must know, such as a missing microphone. The assistant's button opens what was open
// last, its bubbles or its panel (Assistant.qml), and closes it; while either is open
// on its screen, the button is lit and its face filled. Held, it listens until let
// go, as Super does; a right click starts voice mode, or ends it, as a double tap on
// Super does: its pill shows beside the button (VoicePill.qml). In voice mode the
// button stays filled, so the open microphone is never out of sight. Its face tells
// the state by its eyes: they blink now and then while voice mode listens, grow with
// the voice while the person speaks, held or in voice mode, glance up to one side and
// the other while voice mode thinks, and narrow and read from side to side while the
// assistant works; a dot says an action waits for the person.
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
    // Skip silence cutting the recording that ended.
    readonly property bool cutting: kind === "capture" && Capture.cutting
    readonly property bool dictating: dictate && (Dictation.active || Dictation.result !== null)
    readonly property bool hearing: dictate && Dictation.listening && !Dictation.quiet
    readonly property bool wrong: dictate && (Dictation.state === "failed" || Dictation.notice.startsWith("No m") || Dictation.notice.startsWith("Mic"))

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
            || button.hovered && (button.red || button.shared || button.cutting))
        text: button.assistant ? Assistant.notice
            : button.red ? `Recording ${Capture.elapsed} · click to stop`
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

        visible: !button.assistant && !button.red && !button.hearing && !(button.dictate && Dictation.writing)
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

    // The assistant's face (Assistant.icon), whose eyes tell what it does, and
    // its dot. Open, the face is filled and its eyes are holes in it.
    Item {
        visible: button.assistant
        width: face.width
        height: face.height

        Icon {
            id: face

            // What the eyes do: "read" while it works, "hear" while the person
            // speaks, "think" and "blink" in voice mode, or "".
            readonly property string mode: button.working ? "read"
                : button.listening ? "hear"
                : button.voiceState === "thinking" ? "think"
                : button.voiceState === "listening" ? "blink" : ""
            // Where the eyes look, and how open they are: narrowed or grown,
            // and the lids, for a blink.
            property real look
            property real lookUp
            property real squint: mode === "read" ? 0.6 : mode === "hear" ? 1 + 0.6 * Assistant.level : 1
            property real lids: 1
            readonly property string eyes: [6.2, 9.8].map(x => {
                const rx = button.open ? 1 : 1.3, ry = rx * squint * lids;
                return `M${x + look - rx} ${7.5 + lookUp}a${rx} ${ry} 0 1 0 ${2 * rx} 0a${rx} ${ry} 0 1 0 ${-2 * rx} 0z`;
            }).join("")

            function rest() {
                look = 0;
                lookUp = 0;
                lids = 1;
            }

            height: button.half ? 14 : button.tile ? 20 : 18
            color: Theme.textOnAccent
            strokes: Assistant.face
            fills: button.open ? Assistant.face + eyes : eyes

            Behavior on squint { NumberAnimation { duration: 120 } }
            // Read: from left to right, a moment, and back.
            SequentialAnimation {
                running: face.mode === "read"
                loops: Animation.Infinite
                onRunningChanged: if (!running) face.rest()
                NumberAnimation { target: face; property: "look"; to: 1.2; duration: 1080; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 150 }
                NumberAnimation { target: face; property: "look"; to: -1.2; duration: 270; easing.type: Easing.OutSine }
            }
            // Think: up to one side, then the other, back, and a blink.
            SequentialAnimation {
                running: face.mode === "think"
                loops: Animation.Infinite
                onRunningChanged: if (!running) face.rest()
                PauseAnimation { duration: 320 }
                ParallelAnimation {
                    NumberAnimation { target: face; property: "look"; to: 1.1; duration: 380; easing.type: Easing.InOutSine }
                    NumberAnimation { target: face; property: "lookUp"; to: -1.2; duration: 380; easing.type: Easing.InOutSine }
                }
                PauseAnimation { duration: 770 }
                NumberAnimation { target: face; property: "look"; to: -1.1; duration: 380; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 640 }
                ParallelAnimation {
                    NumberAnimation { target: face; property: "look"; to: 0; duration: 380; easing.type: Easing.InOutSine }
                    NumberAnimation { target: face; property: "lookUp"; to: 0; duration: 380; easing.type: Easing.InOutSine }
                }
                PauseAnimation { duration: 170 }
                NumberAnimation { target: face; property: "lids"; to: 0.1; duration: 70 }
                NumberAnimation { target: face; property: "lids"; to: 1; duration: 90 }
            }
            // Blink: twice, now and then, as one does while listening.
            SequentialAnimation {
                running: face.mode === "blink"
                loops: Animation.Infinite
                onRunningChanged: if (!running) face.rest()
                PauseAnimation { duration: 2030 }
                NumberAnimation { target: face; property: "lids"; to: 0.1; duration: 100 }
                NumberAnimation { target: face; property: "lids"; to: 1; duration: 100 }
                NumberAnimation { target: face; property: "lids"; to: 0.1; duration: 100 }
                NumberAnimation { target: face; property: "lids"; to: 1; duration: 100 }
                PauseAnimation { duration: 170 }
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
