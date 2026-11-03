// The assistant's command line, as in the demo: near the top of the screen,
// from its button, the hot corner, or Super+A. Enter asks, and the answer
// comes here, with what it did; Shift+Enter, or a follow-up, goes on in the
// sidebar (AssistantSidebar.qml). The mark at the left is the model, which a
// click switches; the clipboard's text can be added to the question. Until
// its model is on this computer, the line offers to download it
// (AssistantGet.qml).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.controls
import qs.services

Popout {
    id: panel

    // The answer to the line's question, once asked.
    readonly property bool result: Assistant.asked !== "" && Assistant.conversation !== null
    readonly property var answer: {
        const list = Assistant.messages;
        const first = list.findIndex(m => m.role === "user");
        return first < 0 ? [] : list.slice(first + 1);
    }
    readonly property string answerText: answer.filter(m => m.role === "assistant" && m.text).map(m => m.text).join("\n\n")
    property bool clipOpen
    property string clipText

    name: "assistant"
    floating: true
    onResultChanged: {
        if (result)
            more.forceActiveFocus();
        else
            input.forceActiveFocus();
    }
    onVisibleChanged: {
        clipOpen = false;
        if (visible) {
            input.text = "";
            input.forceActiveFocus();
        }
    }

    function ask(sidebar: bool) {
        const text = input.text.trim();
        if (!text)
            return;
        input.text = "";
        Assistant.ask(text);
        if (sidebar)
            Assistant.openSidebar(panel.screenName);
    }

    function followUp() {
        const text = more.text.trim();
        if (!text)
            return;
        more.text = "";
        Assistant.send(text);
        Assistant.openSidebar(panel.screenName);
    }

    PopoverFrame {
        padding: 0

        Column {
            width: Math.min(540, panel.width - 40)

            // Until there is a model: the way to get it.
            Item {
                visible: !Assistant.ready
                width: parent.width
                height: get.height + 28

                AssistantGet {
                    id: get
                    x: 14
                    y: 14
                    width: parent.width - 28
                }
            }

            // The question.
            Item {
                visible: Assistant.ready && !panel.result
                width: parent.width
                height: 50

                ModelButton {
                    id: mark
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextInput {
                    id: input

                    anchors { left: mark.right; leftMargin: 8; right: hint.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    color: Theme.ink
                    selectionColor: Theme.accent
                    selectByMouse: true
                    clip: true
                    font { family: Theme.font; pixelSize: 15 }
                    Keys.onReturnPressed: event => panel.ask((event.modifiers & Qt.ShiftModifier) !== 0)
                    Keys.onEnterPressed: event => panel.ask((event.modifiers & Qt.ShiftModifier) !== 0)
                    Keys.onEscapePressed: panel.dismissed()

                    Text {
                        visible: !input.text
                        text: "Ask anything"
                        color: Theme.inkFaint
                        font: input.font
                    }
                }
                Text {
                    id: hint
                    anchors { right: clip.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: input.text.trim() ? "↵ ask · ⇧↵ sidebar" : ""
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10 }
                }
                LineButton {
                    id: clip
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    tip: "Clipboard"
                    on: panel.clipOpen
                    strokes: "M3.2 3h9.6v11.2H3.2zM6 1.8h4v2.4H6z"
                    onActivated: {
                        panel.clipOpen = !panel.clipOpen;
                        if (panel.clipOpen)
                            paster.running = true;
                    }
                }
            }

            // The clipboard's text, to add to the question.
            Column {
                visible: Assistant.ready && !panel.result && panel.clipOpen
                width: parent.width
                padding: 8
                topPadding: 4
                spacing: 2

                Text {
                    leftPadding: 6
                    bottomPadding: 4
                    text: "CLIPBOARD"
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10; letterSpacing: 0.4 }
                }
                Rectangle {
                    width: parent.width - 16
                    height: 32
                    color: clipHover.hovered ? Theme.veil(0.11) : "transparent"

                    Text {
                        x: 8
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.clipText.trim() ? panel.clipText.replace(/\s+/g, " ") : "Nothing is copied"
                        color: panel.clipText.trim() ? Theme.ink : Theme.inkFaint
                        elide: Text.ElideRight
                        font { family: Theme.font; pixelSize: 13 }
                    }
                    TapHandler {
                        enabled: panel.clipText.trim() !== ""
                        onTapped: {
                            input.text = (input.text ? input.text + " " : "") + panel.clipText.trim();
                            panel.clipOpen = false;
                            input.forceActiveFocus();
                        }
                    }
                    HoverHandler {
                        id: clipHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            // The question asked, and its answer.
            Item {
                visible: Assistant.ready && panel.result
                width: parent.width
                height: 46

                ModelButton {
                    id: markAsked
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors { left: markAsked.right; leftMargin: 8; right: clear.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: Assistant.asked
                    color: Theme.ink
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
                }
                LineButton {
                    id: clear
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    tip: "Clear"
                    strokes: "M5 5l6 6M11 5l-6 6"
                    onActivated: {
                        Assistant.startNew();
                        input.forceActiveFocus();
                    }
                }
            }
            Item {
                visible: Assistant.ready && panel.result
                width: parent.width
                height: box.height + 10

                Rectangle {
                    id: box

                    x: 8
                    y: 2
                    width: parent.width - 16
                    height: body.height + 28
                    color: Theme.veil(0.045)

                    Column {
                        id: body

                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 14

                        Flickable {
                            id: scroller
                            width: parent.width
                            height: Math.min(messages.height, panel.height * 0.45)
                            contentHeight: messages.height
                            clip: true
                            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                            AssistantMessages {
                                id: messages
                                width: scroller.width
                                textSize: 14
                                messages: panel.answer
                            }
                        }
                        Row {
                            spacing: 4

                            DialogButton {
                                visible: Assistant.answering
                                text: "Stop"
                                onActivated: Assistant.stop()
                            }
                            DialogButton {
                                visible: !Assistant.answering && panel.answerText !== ""
                                text: "Copy"
                                strong: true
                                onActivated: Quickshell.execDetached(["wl-copy", "--", panel.answerText])
                            }
                            DialogButton {
                                text: "Open in sidebar"
                                onActivated: Assistant.openSidebar(panel.screenName)
                            }
                        }
                    }
                }
            }
            // A follow-up goes on in the sidebar.
            Item {
                visible: Assistant.ready && panel.result
                width: parent.width
                height: 44

                TextInput {
                    id: more

                    anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.ink
                    selectionColor: Theme.accent
                    selectByMouse: true
                    clip: true
                    font { family: Theme.font; pixelSize: 14 }
                    Keys.onReturnPressed: panel.followUp()
                    Keys.onEnterPressed: panel.followUp()
                    Keys.onEscapePressed: panel.dismissed()

                    Text {
                        visible: !more.text
                        text: "Follow up…  ↵ continues in the sidebar"
                        color: Theme.inkFaint
                        font: more.font
                    }
                }
            }
        }
    }

    Process {
        id: paster
        command: ["wl-paste", "--type", "text", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: panel.clipText = text.slice(0, 2000)
        }
    }

    // The model: its mark, in its color; a click switches to the next.
    component ModelButton: Rectangle {
        id: modelButton

        width: 34
        height: 28
        color: modelHover.hovered && Assistant.models.length > 1 ? Theme.veil(0.08) : "transparent"

        Rectangle {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            color: Assistant.model?.color ?? Theme.accent

            Text {
                anchors.centerIn: parent
                text: Assistant.model?.mark ?? "?"
                color: "#fbfbfd"
                font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
            }
        }
        Icon {
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            visible: Assistant.models.length > 1
            height: 8
            gridWidth: 8
            gridHeight: 8
            color: Theme.inkFaint
            strokes: "M1.5 3l2.5 2.5L6.5 3"
        }
        TapHandler {
            onTapped: Assistant.cycleModel()
        }
        HoverHandler {
            id: modelHover
            cursorShape: Assistant.models.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        ToolTipText {
            shown: modelHover.hovered
            text: `${Assistant.model?.name ?? ""}${Assistant.model?.where === "local" ? " · on this computer" : " · online"}`
                + (Assistant.models.length > 1 ? " · click to switch model" : "")
        }
    }

    component LineButton: Rectangle {
        id: lineButton

        property string strokes
        property string tip
        property bool on
        signal activated

        width: 30
        height: 30
        color: lineButton.on || lineHover.hovered ? Theme.veil(0.11) : "transparent"

        Icon {
            anchors.centerIn: parent
            height: 15
            color: Theme.inkFaint
            strokes: lineButton.strokes
        }
        TapHandler {
            onTapped: lineButton.activated()
        }
        HoverHandler {
            id: lineHover
            cursorShape: Qt.PointingHandCursor
        }
        ToolTipText {
            shown: lineHover.hovered
            text: lineButton.tip
        }
    }

    // A word about what is under the pointer, below it.
    component ToolTipText: Rectangle {
        id: tip

        property bool shown
        property alias text: tipLabel.text

        visible: shown && text !== ""
        z: 10
        y: parent.height + 4
        width: tipLabel.width + 14
        height: 22
        color: Theme.ink

        Text {
            id: tipLabel
            anchors.centerIn: parent
            color: "#fbfbfd"
            font { family: Theme.font; pixelSize: 11 }
        }
    }
}
