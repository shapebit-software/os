// An action of the assistant among its messages, as in the demo: what it is,
// and below, what can be done with it. A proposed one waits: Apply does it
// once, Always allow does it and lets the assistant do the like from then on
// (only changes, never what asks every time), Don't refuses. A change done
// in this session can be undone.
import QtQuick
import qs.services

Rectangle {
    id: card

    required property var message
    readonly property string phase: message.state ?? "running"
    readonly property bool proposed: phase === "proposed"
    readonly property string heading: ({
        proposed: message.risk === "confirm" ? "Confirm" : "Proposed action",
        running: "Working",
        done: message.risk === "read" ? "Checked" : "Applied",
        failed: "Failed",
        declined: "Not done",
        cancelled: "Stopped",
        undone: "Undone",
    })[phase] ?? phase

    width: parent?.width ?? 300
    height: column.height
    color: "transparent"
    border.color: Theme.veil(0.12)

    Column {
        id: column

        width: parent.width

        Column {
            width: parent.width
            padding: 10
            spacing: 5

            Text {
                text: card.heading.toUpperCase()
                color: card.phase === "failed" ? Theme.danger : Theme.inkFaint
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 1 }
            }
            Text {
                width: parent.width - 20
                text: card.message.title ?? ""
                color: Theme.ink
                wrapMode: Text.Wrap
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            Text {
                width: parent.width - 20
                visible: text !== ""
                text: card.phase === "failed" ? card.message.error ?? ""
                    : card.phase === "done" && card.message.risk !== "read" ? "" : card.message.detail ?? ""
                color: card.phase === "failed" ? Theme.danger : Theme.inkFaint
                wrapMode: Text.Wrap
                font { family: Theme.mono; pixelSize: 11 }
            }
        }

        // What can be done with it.
        Rectangle {
            visible: card.proposed || card.message.undoable === true
            width: parent.width
            height: 1
            color: Theme.veil(0.07)
        }
        Row {
            visible: card.proposed
            padding: 7
            leftPadding: 10
            spacing: 5

            CardButton {
                text: card.message.risk === "confirm" ? card.message.title : "Apply"
                strong: true
                onActivated: Assistant.answer(card.message.id, "apply")
            }
            CardButton {
                visible: card.message.risk === "change"
                text: "Always allow"
                tip: Assistant.groups[card.message.group] ?? ""
                onActivated: Assistant.answer(card.message.id, "always")
            }
            CardButton {
                text: card.message.risk === "confirm" ? "Cancel" : "Don't"
                onActivated: Assistant.answer(card.message.id, "decline")
            }
        }
        Item {
            visible: !card.proposed && card.message.undoable === true
            width: parent.width
            height: 30

            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Applied"
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 11 }
            }
            Text {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: "Undo"
                color: Theme.accent
                font { family: Theme.font; pixelSize: 11; weight: Font.Medium }

                TapHandler {
                    onTapped: Assistant.undo(card.message.id)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    component CardButton: Rectangle {
        id: button

        property alias text: label.text
        property bool strong
        property string tip
        signal activated

        width: label.width + 22
        height: 24
        color: strong ? Theme.accent : buttonHover.hovered ? Theme.veil(0.07) : "transparent"
        border.color: strong ? "transparent" : Theme.veil(0.12)

        Text {
            id: label
            anchors.centerIn: parent
            color: button.strong ? "white" : Theme.inkSoft
            font { family: Theme.font; pixelSize: 11; weight: button.strong ? Font.Medium : Font.Normal }
        }

        TapHandler {
            onTapped: button.activated()
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
