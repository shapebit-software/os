// The messages of a conversation, as in the demo: the person's on the right
// in the accent's tint, the assistant's as plain text, its actions as cards
// (AssistantCard.qml). An answer grows as it comes. Messages are listed by
// id, so a growing answer changes only its own item.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services

Column {
    id: list

    // The messages to show, as Assistant.messages holds them.
    property var messages: []
    // The text's size: the line's is larger than the sidebar's.
    property int textSize: 12

    spacing: 12

    Repeater {
        model: ScriptModel {
            values: list.messages.filter(m => m.role !== "assistant" || m.text || m.state !== "done").map(m => m.id)
        }

        Item {
            id: item

            required property string modelData
            readonly property var message: list.messages.find(m => m.id === modelData) ?? ({})

            width: list.width
            height: item.message.role === "action" ? card.height : item.message.role === "user" ? bubble.height : said.height

            // The person's.
            Rectangle {
                id: bubble

                visible: item.message.role === "user"
                anchors.right: parent.right
                width: Math.min(item.width * 0.86, asked.implicitWidth + 22)
                height: asked.height + 16
                color: Qt.alpha(Theme.accent, 0.32)

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
                width: parent.width
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
                width: parent.width
                message: item.message
            }
        }
    }
}
