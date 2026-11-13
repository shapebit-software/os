// The assistant's pill (Assistant.qml), by its button (ButtonPill.qml). Two
// things show in it:
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
import qs.services
import "../services/assistant.js" as Logic

ButtonPill {
    id: pill

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

    name: "voice"
    at: Assistant.pillAt
    shown: (voice || note !== null) && (line.text !== "" || waiting !== null)
    // A note stays while the pointer is on it.
    onHoveredChanged: {
        if (!voice)
            Assistant.peekHovered = hovered;
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

                PillChoice {
                    text: "Go ahead"
                    strong: true
                    onActivated: Assistant.answer(pill.waiting.id, "apply")
                }
                PillChoice {
                    text: "Cancel"
                    onActivated: Assistant.answer(pill.waiting.id, "decline")
                }
            }
        }
    }
}
