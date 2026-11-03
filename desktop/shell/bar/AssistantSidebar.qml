// The assistant's sidebar, as in the demo: one conversation, at the right of
// the screen between the bars, which stays open beside the windows until
// closed. Its header names the conversation (a double click renames it) and
// the workspace it began on, starts a new one, and lists them all
// (AssistantConversations.qml). A reply sent while the assistant works waits
// its turn; Stop ends what is under way, and the queue goes on.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: sidebar

    required property ShellScreen modelData
    readonly property bool here: Assistant.sidebarOn !== "" && Assistant.sidebarOn === (modelData?.name ?? "") && !Lock.locked
    readonly property var conversation: Assistant.conversation
    // Under way in this conversation.
    readonly property bool working: Assistant.busy && Assistant.messages.some(m => ["thinking", "starting", "answering"].includes(m.state)
        || m.state === "proposed" || m.state === "running")

    screen: modelData
    visible: here
    color: "transparent"
    anchors { top: true; bottom: true; right: true }
    implicitWidth: 340 + Theme.gap
    // Beside the windows, between the bars, which it leaves room for.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "assistant"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: frame }
    onHereChanged: {
        if (here)
            reply.forceActiveFocus();
    }

    PopoverFrame {
        id: frame

        y: Theme.gap
        width: 340
        height: sidebar.height - 2 * Theme.gap
        padding: 0

        Item {
            width: 340
            height: frame.height

            // The header.
            Item {
                id: header

                width: parent.width
                height: 40

                Icon {
                    id: sparkle
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 13
                    color: Theme.accent
                    strokes: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
                }
                Text {
                    id: title

                    visible: !renaming.visible
                    anchors { left: sparkle.right; leftMargin: 8; right: badge.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: sidebar.conversation?.title ?? "New conversation"
                    color: Theme.ink
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }

                    TapHandler {
                        enabled: sidebar.conversation !== null
                        onDoubleTapped: {
                            renaming.text = sidebar.conversation.title;
                            renaming.visible = true;
                            renaming.forceActiveFocus();
                            renaming.selectAll();
                        }
                    }
                }
                TextInput {
                    id: renaming

                    visible: false
                    anchors { left: title.left; right: title.right; verticalCenter: parent.verticalCenter }
                    color: Theme.ink
                    selectionColor: Theme.accent
                    clip: true
                    font: title.font
                    function done(keep: bool) {
                        if (keep && text.trim() && sidebar.conversation)
                            Assistant.rename(sidebar.conversation.id, text.trim());
                        visible = false;
                        reply.forceActiveFocus();
                    }
                    Keys.onReturnPressed: done(true)
                    Keys.onEnterPressed: done(true)
                    Keys.onEscapePressed: done(false)
                    onActiveFocusChanged: {
                        if (!activeFocus && visible)
                            done(true);
                    }
                }
                Rectangle {
                    id: badge

                    visible: (sidebar.conversation?.workspace ?? "") !== ""
                    anchors { right: buttons.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: visible ? badgeText.width + 12 : 0
                    height: 18
                    color: Theme.veil(0.12)

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: sidebar.conversation?.workspace ?? ""
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                }
                Row {
                    id: buttons
                    anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }

                    HeaderButton {
                        strokes: "M8 3.5v9M3.5 8h9"
                        onActivated: {
                            Assistant.startNew();
                            reply.forceActiveFocus();
                        }
                    }
                    HeaderButton {
                        strokes: "M2.5 4h11M2.5 8h11M2.5 12h7"
                        onActivated: Assistant.openList(sidebar.modelData.name)
                    }
                    HeaderButton {
                        strokes: "M5 5l6 6M11 5l-6 6"
                        onActivated: Assistant.sidebarOn = ""
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.veil(0.07)
                }
            }

            // The conversation.
            Flickable {
                id: scroller

                anchors { top: header.bottom; bottom: footer.top; left: parent.left; right: parent.right }
                contentHeight: thread.height + 28
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                Column {
                    id: thread

                    x: 12
                    y: 14
                    width: scroller.width - 24
                    spacing: 12

                    AssistantGet {
                        visible: !Assistant.ready
                        width: parent.width
                    }
                    Text {
                        visible: Assistant.ready && Assistant.messages.length === 0
                        width: parent.width
                        text: "Ask a question, or ask for a change: the brightness, the volume, Wi-Fi, an app to open. "
                            + "The assistant shows what it would do before it does it."
                        color: Theme.inkFaint
                        wrapMode: Text.Wrap
                        lineHeight: 1.4
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    AssistantMessages {
                        width: parent.width
                        messages: Assistant.messages
                    }
                }
            }

            // The reply.
            Item {
                id: footer

                anchors.bottom: parent.bottom
                width: parent.width
                height: 55

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.veil(0.07)
                }
                Rectangle {
                    x: 10
                    y: 11
                    width: parent.width - 20
                    height: 34
                    color: Theme.veil(0.07)
                    border.color: Theme.veil(0.12)

                    TextInput {
                        id: reply

                        anchors { left: parent.left; leftMargin: 10; right: send.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        enabled: Assistant.ready
                        color: Theme.ink
                        selectionColor: Theme.accent
                        selectByMouse: true
                        clip: true
                        font { family: Theme.font; pixelSize: 12 }
                        function go() {
                            if (!text.trim())
                                return;
                            Assistant.send(text);
                            text = "";
                        }
                        Keys.onReturnPressed: go()
                        Keys.onEnterPressed: go()
                        Keys.onEscapePressed: Assistant.sidebarOn = ""

                        Text {
                            visible: !reply.text
                            text: sidebar.conversation ? "Reply…" : "Ask anything"
                            color: Theme.inkFaint
                            font: reply.font
                        }
                    }
                    // Send, or Stop while this conversation's request is under way.
                    Rectangle {
                        id: send

                        readonly property bool stopping: sidebar.working && !reply.text.trim()

                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 26
                        height: 26
                        color: Theme.accent
                        opacity: stopping || reply.text.trim() ? 1 : 0.5

                        Icon {
                            anchors.centerIn: parent
                            height: 12
                            color: "white"
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
            }
        }
    }

    component HeaderButton: Rectangle {
        id: headerButton

        property string strokes
        signal activated

        width: 28
        height: 28
        color: headerHover.hovered ? Theme.veil(0.07) : "transparent"

        Icon {
            anchors.centerIn: parent
            height: 13
            color: Theme.inkFaint
            strokeWidth: 1.3
            strokes: headerButton.strokes
        }
        TapHandler {
            onTapped: headerButton.activated()
        }
        HoverHandler {
            id: headerHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
