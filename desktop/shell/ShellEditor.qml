// The bars' layout in Settings > Shell, as in the demo: a small screen with
// the wallpaper and both bars on their edges, each with its three zones, and
// below it the hidden items, on neither bar. An item dragged onto a zone
// moves there, after the others, or before the item it is dropped on; dragged
// onto the hidden items, it leaves the bars (Shell.move). The system menu
// cannot be hidden.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: editor

    // The item being dragged, by id, and where it is over: a zone as
    // "bar zone", or "hidden".
    property string dragged
    property string over

    // The items' pictures: icons on the demo's grid, or text.
    readonly property var icons: ({
        notifications: "M4 11.2V7.4a4 4 0 0 1 8 0v3.8l1.2 1.4H2.8zM6.6 13.6a1.5 1.5 0 0 0 2.8 0",
        microphone: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0zM3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2",
        sound: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z",
        brightness: Brightness.icon,
        network: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z",
        battery: "M2.2 4.6h9.6a1 1 0 0 1 1 1v4.8a1 1 0 0 1-1 1H2.2a1 1 0 0 1-1-1V5.6a1 1 0 0 1 1-1zM14.4 6.6v2.8M3.6 7v2",
        account: "M1.7 8a6.3 6.3 0 1 0 12.6 0a6.3 6.3 0 1 0-12.6 0zM5.9 6.6a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0zM4.1 12.8c.8-1.6 2.2-2.4 3.9-2.4s3.1.8 3.9 2.4",
        apps: "M2.5 2.5h4v4h-4zM9.5 2.5h4v4h-4zM2.5 9.5h4v4h-4zM9.5 9.5h4v4h-4z",
        quick: "M13.5 6.5v7h-7M13.5 13.5 7 7",
    })

    height: screen.height + 8 + hidden.height

    // An item: its picture on glass, dragged by itself. Dropped on, it moves
    // the dragged item before itself (dropped(id)).
    component Tile: Rectangle {
        id: tile

        required property string modelData
        signal dropped(string item)
        signal entered

        implicitWidth: Math.max(24, content.width + 10)
        implicitHeight: 24
        color: Qt.rgba(1, 1, 1, 0.14)
        opacity: editor.dragged === modelData ? 0.35 : 1

        Item {
            id: content

            anchors.centerIn: parent
            width: tile.modelData === "workspaces" ? 37
                : text.visible ? text.width : 13
            height: 13

            Icon {
                visible: editor.icons[tile.modelData] !== undefined
                height: 13
                color: "#f2f3f5"
                strokeWidth: 1.5
                strokes: editor.icons[tile.modelData] ?? ""
            }
            Text {
                id: text
                anchors.centerIn: parent
                visible: tile.modelData === "clock" || tile.modelData === "language"
                text: tile.modelData === "clock" ? "09:41" : Keyboard.code || "EN"
                color: "#f2f3f5"
                font { family: Theme.font; pixelSize: tile.modelData === "clock" ? 10.5 : 9.5; weight: Font.DemiBold }
            }
            Row {
                visible: tile.modelData === "workspaces"
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        width: 7
                        height: 7
                        color: index === 0 ? Theme.accent : Qt.rgba(1, 1, 1, 0.4)
                    }
                }
            }
        }

        DragHandler {
            target: null
            cursorShape: Qt.ClosedHandCursor
            onActiveChanged: {
                if (active) {
                    editor.dragged = tile.modelData;
                    ghost.Drag.active = true;
                } else {
                    ghost.Drag.drop();
                    ghost.Drag.active = false;
                    editor.dragged = "";
                    editor.over = "";
                }
            }
            onCentroidChanged: {
                const at = tile.mapToItem(editor, centroid.position.x, centroid.position.y);
                ghost.x = at.x - ghost.width / 2;
                ghost.y = at.y - ghost.height / 2;
            }
        }
        HoverHandler {
            cursorShape: Qt.OpenHandCursor
        }

        DropArea {
            anchors.fill: parent
            onEntered: tile.entered()
            onDropped: drop => {
                drop.accept();
                if (editor.dragged !== tile.modelData)
                    tile.dropped(editor.dragged);
            }
        }
    }

    Item {
        id: screen

        width: parent.width
        height: Math.round(width * 9 / 16)
        clip: true

        Backdrop {
            anchors.fill: parent
        }

        Repeater {
            model: ["system", "dock"]

            Rectangle {
                id: bar

                required property string modelData
                readonly property string edge: Shell.edgeOf(modelData)
                readonly property string otherEdge: Shell.edgeOf(modelData === "system" ? "dock" : "system")
                readonly property bool vertical: edge === "Left" || edge === "Right"
                readonly property int depth: 36
                readonly property int inset: 6

                x: edge === "Right" ? screen.width - inset - width : inset
                y: edge === "Bottom" ? screen.height - inset - height
                    : vertical && otherEdge === "Top" ? depth + 2 * inset : inset
                width: vertical ? depth : screen.width - 2 * inset
                height: !vertical ? depth
                    : screen.height - 2 * inset - (otherEdge === "Top" || otherEdge === "Bottom" ? depth + inset : 0)
                color: Qt.rgba(0.09, 0.08, 0.15, 0.55)

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: Shell.zoneNames

                        // A zone: a dashed outline, solid under a dragged item.
                        Rectangle {
                            id: zone

                            required property string modelData
                            readonly property string key: `${bar.modelData} ${modelData}`

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: editor.over === key ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            border.width: 1
                            border.color: editor.over === key ? Qt.rgba(1, 1, 1, 0.85)
                                : Qt.rgba(1, 1, 1, editor.dragged ? 0.45 : 0.16)

                            DropArea {
                                anchors.fill: parent
                                onEntered: editor.over = zone.key
                                onExited: {
                                    if (editor.over === zone.key)
                                        editor.over = "";
                                }
                                onDropped: Shell.move(editor.dragged, bar.modelData, zone.modelData, "")
                            }

                            GridLayout {
                                x: bar.vertical ? (parent.width - width) / 2
                                    : zone.modelData === "start" ? 2 : zone.modelData === "end" ? parent.width - width - 2 : (parent.width - width) / 2
                                y: !bar.vertical ? (parent.height - height) / 2
                                    : zone.modelData === "start" ? 2 : zone.modelData === "end" ? parent.height - height - 2 : (parent.height - height) / 2
                                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                                rowSpacing: 3
                                columnSpacing: 3

                                Repeater {
                                    model: Settings.zones[bar.modelData]?.[zone.modelData] ?? []

                                    Tile {
                                        id: tile
                                        Layout.preferredWidth: implicitWidth
                                        Layout.preferredHeight: implicitHeight
                                        onEntered: editor.over = zone.key
                                        onDropped: item => Shell.move(item, bar.modelData, zone.modelData, tile.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The hidden items: a dashed outline, solid under a dragged item that
    // can be hidden.
    Rectangle {
        id: hidden

        readonly property bool target: editor.dragged !== "" && Shell.canHide(editor.dragged)

        y: screen.height + 8
        width: parent.width
        height: Math.max(40, items.height + 16)
        color: Qt.rgba(0.09, 0.08, 0.15, editor.over === "hidden" && target ? 0.92 : 0.8)
        border.width: 1
        border.color: editor.over === "hidden" && target ? Qt.rgba(1, 1, 1, 0.85)
            : Qt.rgba(1, 1, 1, target ? 0.45 : 0.16)

        DropArea {
            anchors.fill: parent
            onEntered: editor.over = "hidden"
            onExited: {
                if (editor.over === "hidden")
                    editor.over = "";
            }
            onDropped: Shell.move(editor.dragged, "", "", "")
        }

        Text {
            anchors.centerIn: parent
            visible: Settings.hiddenItems.length === 0
            text: "Drag items here to hide them"
            color: Qt.rgba(1, 1, 1, 0.6)
            font { family: Theme.font; pixelSize: 11 }
        }
        Flow {
            id: items

            x: 8
            y: 8
            width: parent.width - 16
            spacing: 3

            Repeater {
                model: Settings.hiddenItems

                Tile {
                    id: hiddenTile
                    onEntered: editor.over = "hidden"
                    onDropped: item => Shell.move(item, "", "", hiddenTile.modelData)
                }
            }
        }
    }

    // What follows the pointer while dragging.
    Rectangle {
        id: ghost

        visible: editor.dragged !== ""
        width: 24
        height: 24
        color: Qt.rgba(1, 1, 1, 0.3)
        border.color: Qt.rgba(1, 1, 1, 0.8)
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }
}
