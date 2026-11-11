// The assistant's bubbles, by its button: the conversation's messages, each
// a card of its own, the latest few in full and the older ones dimmed until
// the person scrolls back; below them, the reply line (AssistantReply.qml).
// A tap on Super or a click on the button opens and closes them. A bubble, or
// the button on the reply line, opens the conversation in the panel
// (AssistantDock.qml). For an answer that comes while the assistant is
// hidden, as after a spoken request, they come up by themselves, without the
// reply line or the keyboard, and go again; a click on them keeps them. Until
// the model is on this computer, they offer to download it (AssistantGet.qml).
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Popout {
    id: panel

    readonly property bool peek: Assistant.peeking
    readonly property real wide: Math.min(380, width - 40)

    name: "assistant"
    grab: !peek
    arrow: !peek
    onVisibleChanged: {
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

            AssistantMessages {
                id: messages
                width: scroller.width
                spacing: 6
                textSize: 13
                bubbles: true
                scrolled: scroller.scrolled
                messages: Assistant.messages
                onOpened: Assistant.openPanel(panel.screenName)
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
                Item {
                    visible: Assistant.ready
                    width: parent.width
                    height: 18

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // That an AI answers: people must know (Assistant.qml).
                        text: Assistant.model?.where === "online" ? "AI · online" : "AI · on this computer"
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 12

                        LinkText {
                            visible: Assistant.conversation !== null
                            text: "New"
                            onActivated: {
                                Assistant.startNew();
                                reply.focusInput();
                            }
                        }
                        LinkText {
                            text: "Open in panel"
                            onActivated: Assistant.openPanel(panel.screenName)
                        }
                    }
                }
            }
        }
    }

    component LinkText: Text {
        id: link

        signal activated

        color: linkHover.hovered ? Theme.ink : Theme.inkSoft
        font { family: Theme.font; pixelSize: 11; weight: Font.Medium }

        TapHandler {
            onTapped: link.activated()
        }
        HoverHandler {
            id: linkHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
