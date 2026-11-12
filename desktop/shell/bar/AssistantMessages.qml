// The messages of a conversation: the person's on the right in the accent's
// tint, with what the request told of where they were; the assistant's as
// plain text; its actions as cards (AssistantCard.qml). An answer grows as it
// comes. Messages are listed by id, so a growing answer changes only its own
// item. As bubbles (AssistantBubbles.qml), each is a card of its own, the
// older ones dimmed until the person scrolls back.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.controls
import qs.services
import "../services/assistant.js" as Logic

Column {
    id: list

    // The messages to show, as Assistant.messages holds them.
    property var messages: []
    property int textSize: 12
    // Each message a card of its own, and whether the person scrolled back
    // through them, which shows them all in full.
    property bool bubbles
    property bool scrolled
    readonly property var shown: messages.filter(m => m.role !== "assistant" || m.text || m.state !== "done").map(m => m.id)

    spacing: 12

    Repeater {
        model: ScriptModel {
            values: list.shown
        }

        Item {
            id: item

            required property string modelData
            required property int index
            readonly property var message: list.messages.find(m => m.id === modelData) ?? ({})
            // A bubble's padding around the assistant's words and cards.
            readonly property int pad: list.bubbles && item.message.role !== "user" ? 10 : 0
            readonly property var told: item.message.context ?? ({})

            width: list.width
            height: (item.message.role === "action" ? card.height : item.message.role === "user" ? bubble.height : said.height) + 2 * pad
            opacity: list.bubbles && Logic.dimmed(index, list.shown.length, list.scrolled) && !itemHover.hovered ? 0.45 : 1

            Behavior on opacity { NumberAnimation { duration: 140 } }

            // The bubble's card.
            PopoverFrame {
                visible: item.pad > 0
                width: parent.width
                height: parent.height
                padding: 0
            }
            HoverHandler {
                id: itemHover
            }
            // The person's.
            Rectangle {
                id: bubble

                visible: item.message.role === "user"
                anchors.right: parent.right
                width: Math.min(item.width * 0.86, Math.max(asked.implicitWidth, tag.implicitWidth) + 22)
                height: asked.height + tag.height + 16
                // On its own over the desktop, a bubble is not see-through.
                color: list.bubbles ? Qt.tint(Theme.popoverHover, Qt.alpha(Theme.accent, 0.32)) : Qt.alpha(Theme.accent, 0.32)

                Text {
                    id: asked
                    x: 11
                    y: 8
                    width: parent.width - 22
                    text: item.message.text ?? ""
                    color: Theme.ink
                    wrapMode: Text.Wrap
                    font { family: Theme.font; pixelSize: list.textSize }
                }
                // What the request told of where the person was.
                Text {
                    id: tag

                    readonly property string words: [item.told.selection ? "selected text" : "", item.told.app ?? ""].filter(w => w).join(" · ")

                    visible: words !== ""
                    x: 11
                    anchors.top: asked.bottom
                    width: parent.width - 22
                    height: visible ? implicitHeight + 4 : 0
                    topPadding: 4
                    text: `${item.message.spoken ? "Said, with " : "With "}${words}`
                    color: Theme.inkSoft
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 10 }
                }
                Text {
                    visible: item.message.state === "queued"
                    anchors { right: parent.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "Waiting"
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }
            // The assistant's.
            Column {
                id: said

                visible: item.message.role === "assistant"
                x: item.pad
                y: item.pad
                width: parent.width - 2 * item.pad
                spacing: 4

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: item.message.text ?? ""
                    color: Theme.ink
                    wrapMode: Text.Wrap
                    lineHeight: 1.4
                    textFormat: Text.PlainText
                    font { family: Theme.font; pixelSize: list.textSize }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    readonly property string phase: item.message.state ?? ""
                    text: phase === "starting" ? "Starting the model…"
                        : phase === "thinking" ? "Thinking…"
                        : phase === "stopped" ? "Stopped"
                        : phase === "failed" ? item.message.error ?? "Failed" : ""
                    color: phase === "failed" ? Theme.danger : Theme.inkFaint
                    wrapMode: Text.Wrap
                    font { family: Theme.font; pixelSize: list.textSize - 1; italic: phase !== "failed" }
                }
            }

            AssistantCard {
                id: card
                visible: item.message.role === "action"
                x: item.pad
                y: item.pad
                width: parent.width - 2 * item.pad
                message: item.message
            }
        }
    }
}
