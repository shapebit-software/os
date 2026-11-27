// The assistant's button on a bar, which the shell places by its name,
// "assistant" (feature.qml, Features.qml): it opens what was open last, its
// bubbles or its panel (Assistant.qml), and closes it; while either is open on
// its screen, the button is lit and its face filled. Held, it listens until let
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

    // The ShellBar, its half size, and its size, which the shell gives a
    // feature's item once made (ShellItem.qml).
    property var bar: null
    property bool half

    readonly property string screenName: bar?.modelData?.name ?? ""
    // Voice mode's state (Assistant.voiceState), or "".
    readonly property string voiceState: Assistant.voiceState
    // Bars: held to talk, or speaking in voice mode.
    readonly property bool listening: Assistant.voice === "listening" && ["", "speaking"].includes(voiceState)
    readonly property bool working: !listening && voiceState === ""
        && (Assistant.voice === "writing" || Assistant.busy && !Assistant.attention)

    tile: bar?.dock ?? false
    open: Shell.isOpen("assistant", screenName) || Assistant.panelOn === (bar?.modelData?.name ?? "-")
    fill: listening || Assistant.conversing ? Theme.accent : "transparent"
    onHeld: Assistant.listen()
    onLetGo: Assistant.endListening(true)
    onClicked: Assistant.tap(screenName, () => bar.open("assistant", button))
    onRightClicked: Assistant.toggleConversation(screenName, bar.place(button))

    // The pill, for voice mode started from the keyboard or for a note, shows
    // by this button.
    Connections {
        target: Assistant

        function onPillAsked(screen: string) {
            if (screen === button.screenName && button.visible && button.bar && !Assistant.pillAt)
                Assistant.pillAt = button.bar.place(button);
        }
    }

    Tooltip {
        target: button
        edge: button.bar?.edge ?? "Bottom"
        hovered: button.visible && Assistant.notice !== ""
        text: Assistant.notice
    }

    // The assistant's face (Assistant.icon), whose eyes tell what it does, and
    // its dot. Open, the face is filled and its eyes are holes in it.
    Item {
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
