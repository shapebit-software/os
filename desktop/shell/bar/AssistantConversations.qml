// All of the assistant's conversations, as in the demo: over the screen, the
// latest first, each with the workspace it began on and when it was last
// used; searched by their titles and messages, and narrowed to a workspace.
// One opens in the sidebar. Deleting one is at once, with Undo for a while.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.controls
import qs.services

PanelWindow {
    id: overlay

    required property ShellScreen modelData
    readonly property bool here: Assistant.listOn !== "" && Assistant.listOn === (modelData?.name ?? "") && !Lock.locked
    property string workspace: "All"
    readonly property list<string> workspaces: ["All", ...new Set(Assistant.conversations.map(c => c.workspace).filter(w => w))]
    readonly property var shown: Assistant.conversations.filter(c => (workspace === "All" || c.workspace === workspace)
        && (Assistant.found === null || Assistant.found.includes(c.id)))

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

    function close() {
        Assistant.listOn = "";
    }

    screen: modelData
    visible: here
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // Over the sidebar, and over the bars, which it dims, as in the demo.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "assistant"
    WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onHereChanged: {
        workspace = "All";
        if (here) {
            search.text = "";
            search.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.inkScrim(0.5)

        TapHandler {
            onTapped: overlay.close()
        }
    }

    PopoverFrame {
        id: frame

        x: (overlay.width - width) / 2
        y: Theme.barHeight + Theme.gap * 2
        width: Math.min(760, overlay.width - Theme.gap * 6)
        height: overlay.height - Theme.barHeight - Theme.stripHeight - Theme.gap * 4
        padding: 0

        Item {
            width: frame.width
            height: frame.height

            // Clicks inside stay inside.
            TapHandler {}

            Item {
                id: header

                width: parent.width
                height: 54

                Text {
                    id: heading
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Conversations"
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
                }
                Rectangle {
                    anchors { left: heading.right; leftMargin: 12; right: closer.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
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
                        Keys.onEscapePressed: overlay.close()

                        Text {
                            visible: !search.text
                            text: "Search conversations"
                            color: Theme.inkFaint
                            font: search.font
                        }
                    }
                }
                Rectangle {
                    id: closer

                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 30
                    height: 30
                    color: closeHover.hovered ? Theme.veil(0.07) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        height: 12
                        color: Theme.inkFaint
                        strokes: "M5 5l6 6M11 5l-6 6"
                    }
                    TapHandler {
                        onTapped: overlay.close()
                    }
                    HoverHandler {
                        id: closeHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.veil(0.07)
                }
            }

            // The workspaces they began on.
            Row {
                id: filters

                anchors.top: header.bottom
                x: 16
                topPadding: 10
                bottomPadding: 6
                spacing: 4

                Repeater {
                    model: overlay.workspaces

                    Rectangle {
                        id: filter

                        required property string modelData
                        readonly property bool on: overlay.workspace === modelData

                        width: filterText.width + 20
                        height: 22
                        color: on ? Theme.accentSoft : Theme.veil(0.05)

                        Text {
                            id: filterText
                            anchors.centerIn: parent
                            text: filter.modelData
                            color: filter.on ? Theme.ink : Theme.inkSoft
                            font { family: Theme.mono; pixelSize: 10; letterSpacing: 0.4 }
                        }
                        TapHandler {
                            onTapped: overlay.workspace = filter.modelData
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            ListView {
                id: list

                anchors { top: filters.bottom; bottom: undo.top; left: parent.left; right: parent.right; margins: 8; topMargin: 4 }
                clip: true
                model: ScriptModel {
                    values: overlay.shown
                    objectProp: "id"
                }

                delegate: Rectangle {
                    id: row

                    required property var modelData

                    width: list.width
                    height: 58
                    color: rowHover.hovered ? Theme.veil(0.07) : "transparent"

                    Column {
                        anchors { left: parent.left; leftMargin: 8; right: workspaceText.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 3

                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: Theme.ink
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.snippet.replace(/\s+/g, " ")
                            color: Theme.inkFaint
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                    Text {
                        id: workspaceText
                        anchors { right: time.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        width: 60
                        text: row.modelData.workspace
                        color: Theme.inkFaint
                        elide: Text.ElideRight
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                    Text {
                        id: time
                        anchors { right: remove.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        width: 70
                        horizontalAlignment: Text.AlignRight
                        text: overlay.when(row.modelData.updated)
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                    Rectangle {
                        id: remove

                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 28
                        height: 28
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
                            Assistant.asked = "";
                            Assistant.openSidebar(overlay.modelData.name);
                        }
                    }
                }

                Text {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: Assistant.found !== null ? "No conversation matches" : "No conversations yet"
                    color: Theme.inkFaint
                    font { family: Theme.font; pixelSize: 13 }
                }
            }

            // Undo of the last delete.
            Item {
                id: undo

                anchors.bottom: parent.bottom
                width: parent.width
                height: Assistant.deleted ? 44 : 0
                visible: Assistant.deleted !== null

                Text {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 100
                    text: `Deleted “${Assistant.deleted?.title ?? ""}”`
                    color: Theme.inkSoft
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
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
    }
}
