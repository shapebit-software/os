// The assistant's panel, at the right of the screen between the bars: one
// conversation, opened from the bubbles (AssistantBubbles.qml) or by pushing the
// pointer against the right edge (AssistantEdge.qml). It lies over the
// windows, or is docked: then it looks like a tile and reserves its width,
// so the windows retile beside it, though it is none of them and stays on
// every workspace. Its left edge is dragged to resize it. A narrow screen
// has no room to dock it.
//
// Its header names the conversation (a double click renames it); the buttons
// at its left start a new one and list them all, with a search, and those at
// its right show the conversation as bubbles again, and dock or undock the
// panel. A conversation belongs to no workspace. The assistant's button, or a
// tap on Super, opens and closes it; over the windows, a click on another
// window, or on the bars off their items (ShellBar.qml), closes it, as Escape
// does, while their buttons, such as the apps' or dictation's, leave it. A reply sent while the
// assistant works waits its turn; Stop ends what is under way, and the queue
// goes on. Deleting a conversation is at once, with Undo for a while.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.controls
import qs.services
import "../services/assistant.js" as Logic

PanelWindow {
    id: dock

    required property ShellScreen modelData
    readonly property bool here: Assistant.panelOn !== "" && Assistant.panelOn === (modelData?.name ?? "") && !Lock.locked
    readonly property var conversation: Assistant.conversation
    // Too narrow to leave the windows room beside the panel.
    readonly property bool narrow: (modelData?.width ?? 0) < Logic.narrowBelow
    // Whether the models unfold, to choose another.
    property bool choosing
    readonly property bool docked: Logic.reserves(Assistant.view, narrow)
    readonly property int wide: Logic.width(Settings.assistantWidth, modelData?.width ?? 0)
    // A tile's corners and edge, as the compositor draws the windows'
    // (Compositor.setDecoration).
    readonly property int tileRadius: Settings.windowCorners === "Rounded" ? 9 : Settings.windowDecoration === "Soft" ? 4 : 0
    readonly property bool tileBorder: Settings.windowDecoration === "Hairline" || Settings.windowDecoration === "Soft"
    readonly property bool tileShadow: Settings.windowDecoration === "Shadow" || Settings.windowDecoration === "Soft"

    // The list of conversations, narrowed by the search.
    readonly property var listed: Assistant.conversations.filter(c => Assistant.found === null || Assistant.found.includes(c.id))

    function when(seconds: real): string {
        const date = new Date(seconds * 1000);
        const midnight = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        const days = Math.round((midnight(new Date()) - midnight(date)) / 86400000);
        if (days === 0)
            return Qt.formatTime(date, Settings.timeFormat === "12-hour" ? "h:mm AP" : "HH:mm");
        if (days === 1)
            return "Yesterday";
        if (days < 7)
            return Qt.formatDate(date, "ddd");
        return Qt.formatDate(date, "MMM d");
    }

    function takeKeyboard() {
        if (Assistant.listing)
            search.forceActiveFocus();
        else
            reply.focusInput();
    }

    // Escape: over the windows, the panel hides; docked, it stays and gives
    // the keyboard back.
    function leave() {
        if (docked)
            Assistant.panelFocused = false;
        else
            Assistant.hide();
    }

    screen: modelData
    visible: here
    color: "transparent"
    anchors { top: true; bottom: true; right: true }
    implicitWidth: wide + Theme.gap
    // Between the bars, which it leaves room for; docked, the windows leave
    // room for it.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: docked ? implicitWidth : 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "assistant"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: frame }
    onHereChanged: {
        if (here && Assistant.panelFocused)
            takeKeyboard();
    }

    Connections {
        target: Assistant

        function onPanelFocusedChanged() {
            if (dock.here && Assistant.panelFocused)
                dock.takeKeyboard();
        }

        function onListingChanged() {
            search.text = "";
            if (dock.here && Assistant.panelFocused)
                dock.takeKeyboard();
        }
    }

    // The keyboard is the panel's while it has the focus. A click outside it
    // and the bars gives it back, docked; over the windows, it closes the
    // panel.
    HyprlandFocusGrab {
        active: dock.here && (Assistant.panelFocused || !dock.docked)
        windows: [dock, ...Shell.bars]
        onCleared: {
            if (dock.docked)
                Assistant.panelFocused = false;
            else
                Assistant.dismiss();
        }
    }

    Item {
        id: frame

        y: Theme.gap
        width: dock.wide
        height: dock.height - 2 * Theme.gap

        // A click in the panel gives it the keyboard.
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onPressedChanged: {
                if (pressed)
                    Assistant.panelFocused = true;
            }
        }

        // Over the windows, a popover's glass; docked, a tile.
        PopoverFrame {
            visible: !dock.docked
            width: parent.width
            height: parent.height
            padding: 0
        }
        RectangularShadow {
            visible: dock.docked && dock.tileShadow
            anchors.fill: parent
            radius: dock.tileRadius
            offset.y: 6
            blur: 18
            color: Theme.shadow(0.22)
        }
        Rectangle {
            visible: dock.docked
            anchors.fill: parent
            radius: dock.tileRadius
            color: Theme.popoverHover
            border.color: dock.tileBorder ? Theme.popoverRing : "transparent"
        }

        // The header.
        Item {
            id: header

            width: parent.width
            height: 40

            // The conversations, at the left: a new one, and all of them.
            Row {
                id: conversationButtons
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }

                AssistantButton {
                    tip: "New conversation"
                    tipLeft: true
                    strokes: "M8 3.5v9M3.5 8h9"
                    onActivated: {
                        Assistant.startNew();
                        reply.focusInput();
                    }
                }
                AssistantButton {
                    tip: "Conversations"
                    tipLeft: true
                    on: Assistant.listing
                    strokes: "M2.5 4h11M2.5 8h11M2.5 12h7"
                    onActivated: Assistant.list(!Assistant.listing)
                }
            }
            Text {
                id: title

                visible: !renaming.visible
                anchors { left: conversationButtons.right; leftMargin: 8; right: viewButtons.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: Assistant.listing ? "Conversations" : dock.conversation?.title ?? "New conversation"
                color: Theme.ink
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }

                TapHandler {
                    enabled: dock.conversation !== null && !Assistant.listing
                    onDoubleTapped: {
                        renaming.text = dock.conversation.title;
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
                    if (keep && text.trim() && dock.conversation)
                        Assistant.rename(dock.conversation.id, text.trim());
                    visible = false;
                    reply.focusInput();
                }
                Keys.onReturnPressed: done(true)
                Keys.onEnterPressed: done(true)
                Keys.onEscapePressed: done(false)
                onActiveFocusChanged: {
                    if (!activeFocus && visible)
                        done(true);
                }
            }
            // How it shows, at the right: as bubbles, or the panel docked.
            Row {
                id: viewButtons
                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }

                AssistantButton {
                    tip: "Show as bubbles"
                    strokes: "M2.5 3h8v5h-8zM5.5 10.5h8v3h-8z"
                    onActivated: Assistant.openBubbles(dock.modelData.name)
                }
                AssistantButton {
                    visible: !dock.narrow
                    tip: dock.docked ? "Over the windows" : "Beside the windows"
                    on: dock.docked
                    strokes: "M2.5 2.5h11v11h-11zM10 2.5v11"
                    onActivated: Assistant.dock(!dock.docked, dock.narrow)
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

            visible: !Assistant.listing
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

            visible: !Assistant.listing
            anchors.bottom: parent.bottom
            width: parent.width
            height: visible ? lower.height + 21 : 0

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Theme.veil(0.07)
            }
            Column {
                id: lower
                x: 10
                y: 11
                width: parent.width - 20
                spacing: 6

                // The model that answers, which unfolds the others above it.
                AssistantModelList {
                    visible: dock.choosing
                    width: parent.width
                    onChosen: dock.choosing = false
                }
                Rectangle {
                    width: modelName.width + 30
                    height: 24
                    color: dock.choosing ? Theme.veil(0.12) : modelHover.hovered ? Theme.veil(0.07) : "transparent"

                    Text {
                        id: modelName
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
                        strokes: dock.choosing ? "M4 6l4 4 4-4" : "M4 10l4-4 4 4"
                    }
                    TapHandler {
                        onTapped: dock.choosing = !dock.choosing
                    }
                    HoverHandler {
                        id: modelHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                AssistantReply {
                    id: reply
                    width: parent.width
                    onEscaped: dock.leave()
                }
            }
        }

        // All the conversations.
        Item {
            visible: Assistant.listing
            anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }

            Rectangle {
                id: searchBox

                x: 10
                y: 10
                width: parent.width - 20
                height: 30
                color: Theme.veil(0.07)
                border.color: Theme.veil(0.12)

                Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 12
                    color: Theme.inkFaint
                    strokeWidth: 1.5
                    strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0M10.4 10.4L14 14"
                }
                TextInput {
                    id: search

                    anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    color: Theme.ink
                    selectionColor: Theme.accent
                    clip: true
                    font { family: Theme.font; pixelSize: 12 }
                    onTextChanged: Assistant.search(text)
                    Keys.onEscapePressed: Assistant.list(false)

                    Text {
                        visible: !search.text
                        text: "Search conversations"
                        color: Theme.inkFaint
                        font: search.font
                    }
                }
            }

            ListView {
                id: list

                anchors { top: searchBox.bottom; bottom: undo.top; left: parent.left; right: parent.right; margins: 8; topMargin: 6 }
                clip: true
                model: ScriptModel {
                    values: dock.listed
                    objectProp: "id"
                }

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: list.width
                    height: 54
                    color: rowHover.hovered || row.modelData.id === dock.conversation?.id ? Theme.veil(0.07) : "transparent"

                    Column {
                        anchors { left: parent.left; leftMargin: 8; right: time.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: Theme.ink
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.snippet.replace(/\s+/g, " ")
                            color: Theme.inkFaint
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 11 }
                        }
                    }
                    Text {
                        id: time
                        anchors { right: remove.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        horizontalAlignment: Text.AlignRight
                        text: dock.when(row.modelData.updated)
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                    Rectangle {
                        id: remove

                        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        width: 26
                        height: 26
                        opacity: rowHover.hovered ? 1 : 0
                        color: removeHover.hovered ? Theme.veil(0.1) : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            height: 13
                            color: Theme.inkFaint
                            strokes: "M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.6 8.5h5.8l.6-8.5"
                        }
                        TapHandler {
                            onTapped: Assistant.remove(row.modelData.id)
                        }
                        HoverHandler {
                            id: removeHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.veil(0.07)
                    }
                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            Assistant.open(row.modelData.id);
                            Assistant.list(false);
                        }
                    }
                }

                Text {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: Assistant.found !== null ? "No conversation matches" : "No conversations yet"
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 12 }
                }
            }

            // Undo of the last delete.
            Item {
                id: undo

                anchors.bottom: parent.bottom
                width: parent.width
                height: Assistant.deleted ? 40 : 0
                visible: Assistant.deleted !== null

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80
                    text: `Deleted “${Assistant.deleted?.title ?? ""}”`
                    color: Theme.inkSoft
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "Undo"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

                    TapHandler {
                        onTapped: Assistant.restore()
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // The left edge, dragged, resizes the panel. The window is anchored
        // at the right, so the width is how far the pointer is from there.
        Item {
            id: grip

            x: -3
            width: 8
            height: parent.height

            HoverHandler {
                cursorShape: Qt.SizeHorCursor
            }
            DragHandler {
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onCentroidChanged: {
                    if (active)
                        Settings.assistantWidth = Logic.width(dock.width - centroid.scenePosition.x - Theme.gap, dock.modelData.width);
                }
            }
        }
    }
}
