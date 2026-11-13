// The assistant's pill (Assistant.qml): beside its button, off its bar, as a
// panel opens (Popout.qml), with an arrow to it; with no button on the bars,
// in the bottom right corner. It takes no keyboard, so the application keeps
// it. Two things show in it:
// - Voice mode, while it is on, on the screen it began on: the answer, until
//   the person speaks again, or a word when what they said did nothing. What
//   they say is never shown, as in dictation: the button's face shows that it
//   listens, hears and thinks. An action that waits is one row: to say yes or
//   no to, or, for what yes can't be said to, to click. Nothing is kept: the
//   conversation behind it is forgotten when voice mode ends.
// - A note (Assistant.note): an answer, or an action, that came while the
//   assistant was hidden, as the bubbles would show it; an action that waits
//   has its buttons. It goes by itself after a few seconds, unless it waits or
//   the pointer is on it; a click on it opens the bubbles.
// Until there is a line, it is not there.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services
import "../services/assistant.js" as Logic

PanelWindow {
    id: pill

    required property ShellScreen modelData

    readonly property var at: Assistant.pillAt
    readonly property bool voice: Assistant.conversing
    readonly property var note: Assistant.note
    readonly property var waiting: voice ? Assistant.voiceWaiting
        : note?.role === "action" && note.state === "proposed" ? note : null
    readonly property var last: voice ? Assistant.voiceLast : note
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
        if (!voice && last?.role === "action" && last.state === "done")
            return { kind: "notice", text: `${last.title}: done` };
        return { kind: "", text: "" };
    }
    readonly property real margin: Theme.gap

    screen: modelData
    visible: (voice || note !== null) && (at?.screen ?? "") === modelData.name && (line.text !== "" || waiting !== null)
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
        padding: 10
        opacity: pill.visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        // A note stays while the pointer is on it.
        HoverHandler {
            enabled: !pill.voice
            onHoveredChanged: Assistant.peekHovered = hovered
        }

        Column {
            width: 320
            spacing: 6

            Text {
                visible: text !== ""
                width: parent.width
                text: markdown || pill.line.text
                color: pill.line.kind === "error" ? Theme.danger
                    : pill.line.kind === "answer" ? Theme.ink
                    : pill.line.kind === "notice" ? Theme.inkSoft : Theme.inkFaint
                wrapMode: Text.Wrap
                maximumLineCount: pill.line.kind === "answer" ? 5 : 2
                elide: Text.ElideRight
                // An answer as the bubbles show it, without its formatting marks.
                readonly property string markdown: pill.line.kind === "answer" ? Logic.markdown(pill.line.text, Theme.accent) : ""
                textFormat: markdown ? Text.MarkdownText : Text.PlainText
                lineHeight: 1.15
                font { family: Theme.font; pixelSize: 14 }

                // A note's words open the bubbles; an action's buttons are apart.
                TapHandler {
                    enabled: !pill.voice
                    onTapped: Assistant.openNote()
                }
                HoverHandler {
                    enabled: !pill.voice
                    cursorShape: Qt.PointingHandCursor
                }
            }
            // An action that waits.
            Row {
                visible: pill.waiting !== null && pill.phase !== "speaking"
                width: parent.width
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool spoken: pill.voice && pill.waiting?.risk === "change"
                    width: parent.width - (spoken ? 0 : buttons.width + 6)
                    text: spoken ? `${pill.waiting?.title ?? ""}? Say yes or no.` : `${pill.waiting?.title ?? ""}?`
                    color: Theme.ink
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                }
                Row {
                    id: buttons
                    visible: !pill.voice || pill.waiting?.risk !== "change"
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
    // An arrow from the pill to the assistant's button, as a popover has
    // (Popout.qml), so that the answer is plainly the face's.
    Item {
        readonly property string edge: frame.edge
        readonly property real centerX: edge === "Left" ? frame.x - 3.5
            : edge === "Right" ? frame.x + frame.width + 3.5
            : Math.max(frame.x + 12, Math.min(frame.x + frame.width - 12, frame.anchor.x + frame.anchor.width / 2))
        readonly property real centerY: edge === "Top" ? frame.y - 3.5
            : edge === "Bottom" ? frame.y + frame.height + 3.5
            : Math.max(frame.y + 12, Math.min(frame.y + frame.height - 12, frame.anchor.y + frame.anchor.height / 2))

        visible: frame.placed
        opacity: frame.opacity
        x: centerX - width / 2
        y: centerY - height / 2
        width: 18
        height: 9
        rotation: ({ "Bottom": 0, "Top": 180, "Left": 90, "Right": -90 })[edge] ?? 0
        clip: true

        Rectangle {
            x: 9 - width / 2
            y: -width / 2
            width: 12.7
            height: 12.7
            rotation: 45
            color: parent.edge === "Top" ? Theme.popoverTop : Theme.popoverBottom
            border.color: Theme.popoverRing
        }
    }
}
