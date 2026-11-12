// The assistant's reply line, in the bubbles and in the panel
// (AssistantBubbles.qml, AssistantDock.qml): the request, and above it what
// the request will tell of where the person is, the selected text and the
// focused window, each to take off before sending. Enter sends; while this
// conversation's request is under way and the line is empty, the button
// stops it. On a ChatGPT plan, below it, that the plan is used, and where to
// manage its usage, as OpenAI asks.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Column {
    id: reply

    property int textSize: 12
    property string placeholder: Assistant.conversation ? "Reply…" : "Ask anything"
    // Under way in this conversation.
    readonly property bool working: Assistant.busy && Assistant.messages.some(m => ["thinking", "starting", "answering"].includes(m.state)
        || m.state === "proposed" || m.state === "running")
    readonly property var told: Assistant.context
    readonly property var chips: [
        ...(told.selection ? [{ name: "selection", text: `Selected text · ${told.selection.length} characters` }] : []),
        ...(told.app || told.title ? [{ name: "window", text: [told.app, told.title].filter(w => w).join(" · ") }] : []),
    ]
    signal escaped

    function focusInput() {
        input.forceActiveFocus();
    }

    function go() {
        if (!input.text.trim())
            return;
        Assistant.send(input.text);
        input.text = "";
    }

    spacing: 6

    Flow {
        visible: reply.chips.length > 0
        width: parent.width
        spacing: 4

        Repeater {
            model: reply.chips

            Rectangle {
                id: chip

                required property var modelData

                width: Math.min(reply.width, chipText.implicitWidth + 30)
                height: 20
                color: Theme.veil(0.07)

                Text {
                    id: chipText
                    x: 7
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.text
                    color: Theme.inkSoft
                    elide: Text.ElideRight
                    font { family: Theme.mono; pixelSize: 10 }
                }
                Icon {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    height: 9
                    color: Theme.inkFaint
                    strokes: "M4 4l8 8M12 4l-8 8"
                }
                TapHandler {
                    onTapped: {
                        if (chip.modelData.name === "window") {
                            Assistant.drop("app");
                            Assistant.drop("title");
                        } else {
                            Assistant.drop(chip.modelData.name);
                        }
                    }
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 34
        color: Theme.veil(0.07)
        border.color: Theme.veil(0.12)

        TextInput {
            id: input

            anchors { left: parent.left; leftMargin: 10; right: send.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
            enabled: Assistant.ready
            color: Theme.ink
            selectionColor: Theme.accent
            selectByMouse: true
            clip: true
            font { family: Theme.font; pixelSize: reply.textSize }
            Keys.onReturnPressed: reply.go()
            Keys.onEnterPressed: reply.go()
            Keys.onEscapePressed: reply.escaped()

            Text {
                visible: !input.text
                width: parent.width
                text: reply.placeholder
                color: Theme.inkFaint
                elide: Text.ElideRight
                font: input.font
            }
        }
        // Send, or Stop while this conversation's request is under way.
        Rectangle {
            id: send

            readonly property bool stopping: reply.working && !input.text.trim()

            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            width: 26
            height: 26
            color: Theme.accent
            opacity: stopping || input.text.trim() ? 1 : 0.5

            Icon {
                anchors.centerIn: parent
                height: 12
                color: Theme.textOnAccent
                strokeWidth: 1.8
                strokes: send.stopping ? "" : "M8 13V3M3.5 7.5 8 3l4.5 4.5"
                fills: send.stopping ? "M4.5 4.5h7v7h-7z" : ""
            }
            TapHandler {
                onTapped: send.stopping ? Assistant.stop() : reply.go()
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    Row {
        visible: Assistant.model?.provider === "chatgpt"
        spacing: 6

        Text {
            text: "Using ChatGPT plan"
            color: Theme.inkFaint
            font { family: Theme.font; pixelSize: 11 }
        }
        Text {
            text: "Manage usage"
            color: Theme.accent
            font { family: Theme.font; pixelSize: 11; weight: Font.Medium }

            TapHandler {
                onTapped: Qt.openUrlExternally(Assistant.providers.chatgpt?.usage ?? "https://chatgpt.com/settings/usage")
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
