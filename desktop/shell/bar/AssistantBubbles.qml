// The assistant's bubbles, by its button: the conversation's messages, each
// a card of its own, the latest few in full and the older ones dimmed until
// the person scrolls back; below them, the reply line (AssistantReply.qml).
// Bubbles above the top edge fade into it rather than being cut off there.
// A tap on Super or a click on the button opens and closes them; a click
// elsewhere leaves them, and only takes the keyboard away. Below the reply
// line are the model that answers, which unfolds the others to choose from,
// and buttons for a new conversation and to open this one in the panel
// (AssistantDock.qml). For an answer that comes while the assistant is
// hidden, as after a spoken request, they come up by themselves, without the
// reply line or the keyboard, and go again; a click on them keeps them. Until
// the model is on this computer, they offer to download it (AssistantGet.qml).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.controls
import qs.services

Popout {
    id: panel

    readonly property bool peek: Assistant.peeking
    readonly property real wide: Math.min(380, width - 40)
    // The models are unfolded, to choose one.
    property bool choosing

    name: "assistant"
    grab: !peek
    stays: true
    arrow: !peek
    onVisibleChanged: {
        choosing = false;
        if (visible && !peek)
            reply.focusInput();
    }
    onPeekChanged: {
        if (visible && !peek)
            reply.focusInput();
    }

    Column {
        width: panel.wide
        spacing: 6

        HoverHandler {
            onHoveredChanged: Assistant.peekHovered = hovered
        }
        TapHandler {
            enabled: panel.peek
            onTapped: Assistant.keepPeek()
        }

        Flickable {
            id: scroller

            // The person went back through the bubbles.
            readonly property bool scrolled: contentY < contentHeight - height - 4

            visible: Assistant.messages.length > 0
            width: parent.width
            height: Math.min(contentHeight, panel.height * (panel.peek ? 0.3 : 0.5))
            contentHeight: messages.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
            onHeightChanged: contentY = Math.max(0, contentHeight - height)
            // With bubbles above, the top edge fades them out.
            layer.enabled: contentY > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: fade
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            AssistantMessages {
                id: messages
                width: scroller.width
                spacing: 6
                textSize: 13
                bubbles: true
                scrolled: scroller.scrolled
                messages: Assistant.messages
            }
        }

        // The mask of that fade: clear at the top, solid below it.
        Rectangle {
            id: fade

            visible: false
            layer.enabled: true
            width: scroller.width
            height: scroller.height
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.veil(0.35) }
                GradientStop { position: Math.min(1, 28 / Math.max(1, fade.height)); color: Theme.ink }
            }
        }

        PopoverFrame {
            visible: !panel.peek
            width: parent.width
            padding: 10

            Column {
                width: panel.wide - 20
                spacing: 8

                AssistantGet {
                    visible: !Assistant.ready
                    width: parent.width
                }
                AssistantReply {
                    id: reply
                    visible: Assistant.ready
                    width: parent.width
                    textSize: 14
                    onEscaped: panel.dismissed()
                }
                // The model that answers, which unfolds the others, and the
                // buttons: a new conversation, and this one in the panel.
                Item {
                    width: parent.width
                    height: 28

                    Rectangle {
                        id: chooser

                        anchors.verticalCenter: parent.verticalCenter
                        width: chosen.width + 30
                        height: 24
                        color: panel.choosing ? Theme.veil(0.12) : chooserHover.hovered ? Theme.veil(0.07) : "transparent"

                        // Its name says that an AI answers: people must know
                        // (Assistant.qml).
                        Text {
                            id: chosen
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Assistant.model?.name ?? "No model"
                            color: Theme.inkSoft
                            font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
                        }
                        Icon {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            height: 10
                            color: Theme.inkFaint
                            strokeWidth: 1.5
                            strokes: panel.choosing ? "M4 10l4-4 4 4" : "M4 6l4 4 4-4"
                        }
                        TapHandler {
                            onTapped: panel.choosing = !panel.choosing
                        }
                        HoverHandler {
                            id: chooserHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }

                        AssistantButton {
                            visible: Assistant.conversation !== null
                            tip: "New conversation"
                            tipAbove: true
                            strokes: "M8 3.5v9M3.5 8h9"
                            onActivated: {
                                Assistant.startNew();
                                reply.focusInput();
                            }
                        }
                        AssistantButton {
                            tip: "Open in panel"
                            tipAbove: true
                            strokes: "M2.5 2.5h11v11h-11zM10 2.5v11"
                            onActivated: Assistant.openPanel(panel.screenName)
                        }
                    }
                }
                // All the models, unfolded.
                AssistantModelList {
                    visible: panel.choosing
                    width: parent.width
                    onChosen: panel.choosing = false
                }
            }
        }
    }
}
