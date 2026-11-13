// Voice mode's pill (Assistant.qml), only while voice mode is on: beside the
// assistant's button, off its bar, as a panel opens (Popout.qml), on the
// screen voice mode began on; with no button on the bars, in the bottom right
// corner. Text only, one line: the answer, until the person speaks again, or a
// word when what they said did nothing. What they say is never shown, as in
// dictation: the button's face shows that it listens, hears and thinks. Until
// there is a line, it is not there. An action that waits is
// one row: to say yes or no to, or, for what yes can't be said to, to click.
// The button tells the state too (QuickButton.qml). Nothing here is kept: the
// conversation behind it is forgotten when voice mode ends. It takes no
// keyboard, so the application keeps it.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: pill

    required property ShellScreen modelData

    readonly property var at: Assistant.voiceAt
    readonly property var waiting: Assistant.voiceWaiting
    readonly property var last: Assistant.voiceLast
    readonly property string phase: Assistant.voiceState
    // The one line, and how it shows: "answer", "notice", "error", or none.
    // The state is the button's to show (QuickButton.qml).
    readonly property var line: {
        if (phase === "speaking")
            return { kind: "", text: "" };
        if (Assistant.voiceNotice)
            return { kind: "notice", text: Assistant.voiceNotice };
        if (phase === "thinking")
            return { kind: "", text: "" };
        if (last?.role === "assistant" && last.state === "failed")
            return { kind: "error", text: last.error ?? "It failed." };
        if (last?.role === "assistant" && last.text)
            return { kind: "answer", text: last.text };
        if (last?.role === "action" && last.state === "failed")
            return { kind: "error", text: last.error ?? `${last.title} failed.` };
        return { kind: "", text: "" };
    }
    readonly property real margin: Theme.gap

    screen: modelData
    visible: Assistant.conversing && (at?.screen ?? "") === modelData.name && (line.text !== "" || waiting !== null)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "voice"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: frame }

    component Choice: Rectangle {
        id: choice

        property alias text: label.text
        property bool strong
        signal activated

        width: label.width + 16
        height: 22
        color: strong ? Theme.accent : choiceHover.hovered ? Theme.veil(0.12) : Theme.veil(0.07)

        Text {
            id: label
            anchors.centerIn: parent
            color: choice.strong ? Theme.textOnAccent : Theme.ink
            font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
        }
        TapHandler {
            onTapped: choice.activated()
        }
        HoverHandler {
            id: choiceHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    PopoverFrame {
        id: frame

        readonly property bool placed: pill.at?.rect !== undefined && pill.at?.rect !== null
        readonly property rect anchor: placed ? pill.at.rect : Qt.rect(0, 0, 0, 0)
        readonly property string edge: placed ? pill.at.edge : ""
        readonly property real depth: placed ? pill.at.depth : 0
        // Clear of the dock in the corner.
        readonly property real fromBottom: 14 + (Settings.dock === "Bottom" ? Theme.stripHeight + Theme.gap : 0)

        function clamp(at: real, size: real, length: real): real {
            return Math.max(pill.margin, Math.min(length - pill.margin - size, at - size / 2));
        }

        x: edge === "Left" ? depth + pill.margin
            : edge === "Right" ? pill.width - depth - pill.margin - width
            : edge === "" ? pill.width - width - pill.margin - 14
            : clamp(anchor.x + anchor.width / 2, width, pill.width)
        y: edge === "Top" ? depth + pill.margin
            : edge === "Bottom" ? pill.height - depth - pill.margin - height
            : edge === "" ? pill.height - height - pill.margin - fromBottom
            : clamp(anchor.y + anchor.height / 2, height, pill.height)
        padding: 9

        Column {
            width: 280
            spacing: 6

            Text {
                visible: text !== ""
                width: parent.width
                text: pill.line.text
                color: pill.line.kind === "error" ? Theme.danger
                    : pill.line.kind === "answer" ? Theme.ink
                    : pill.line.kind === "notice" ? Theme.inkSoft : Theme.inkFaint
                wrapMode: Text.Wrap
                maximumLineCount: pill.line.kind === "answer" ? 4 : 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font { family: Theme.font; pixelSize: 12 }
            }
            // An action that waits.
            Row {
                visible: pill.waiting !== null && pill.phase !== "speaking"
                width: parent.width
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (pill.waiting?.risk === "change" ? 0 : buttons.width + 6)
                    text: pill.waiting?.risk === "change" ? `${pill.waiting?.title ?? ""}? Say yes or no.` : `${pill.waiting?.title ?? ""}?`
                    color: Theme.ink
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                }
                Row {
                    id: buttons
                    visible: pill.waiting?.risk !== "change"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Choice {
                        text: "Go ahead"
                        strong: true
                        onActivated: Assistant.answer(pill.waiting.id, "apply")
                    }
                    Choice {
                        text: "Cancel"
                        onActivated: Assistant.answer(pill.waiting.id, "decline")
                    }
                }
            }
        }
    }
}
