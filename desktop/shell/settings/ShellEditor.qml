// The bars' layout in Settings > Shell, as in the demo: a small screen with
// the wallpaper and both bars on their edges, each with its three zones;
// below it, what can be done with the selected item; and below that the
// hidden items, on neither bar.
//
// An item dragged onto a zone moves to where the line between items shows
// (Shell.move); dragged onto the hidden items, it leaves the bars. A click
// selects an item: buttons move it one place earlier or later, past its
// zone's edge into the next zone (Shell.step), make a button on the dock
// full or half size, and hide or show it. The system menu cannot be hidden.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.controls
import qs.services
import qs.wallpaper

Item {
    id: editor

    // The item being dragged, by id, and where it is over: a zone as
    // "bar zone", or "hidden"; and at which index of that zone it would land.
    property string dragged
    property string over
    property int at: -1
    // The selected item, by id, and where it is (Shell.find).
    property string selected
    readonly property var place: selected ? Shell.find(selected) : null

    // The tiles' sizes: a full one, and a half one, two across the bar.
    readonly property int tileSize: 28
    readonly property int halfSize: (tileSize - 3) / 2

    // The items' pictures: icons on the demo's grid, or text.
    readonly property var icons: ({
        downloads: "M8 2v8.4M4.6 7l3.4 3.4L11.4 7M2.6 13.4h10.8",
        notifications: "M4 11.2V7.4a4 4 0 0 1 8 0v3.8l1.2 1.4H2.8zM6.6 13.6a1.5 1.5 0 0 0 2.8 0",
        microphone: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0zM3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2",
        sound: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z",
        brightness: Brightness.icon,
        network: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z",
        battery: "M2.2 4.6h9.6a1 1 0 0 1 1 1v4.8a1 1 0 0 1-1 1H2.2a1 1 0 0 1-1-1V5.6a1 1 0 0 1 1-1zM14.4 6.6v2.8M3.6 7v2",
        account: "M1.7 8a6.3 6.3 0 1 0 12.6 0a6.3 6.3 0 1 0-12.6 0zM5.9 6.6a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0zM4.1 12.8c.8-1.6 2.2-2.4 3.9-2.4s3.1.8 3.9 2.4",
        apps: "M2.5 2.5h4v4h-4zM9.5 2.5h4v4h-4zM2.5 9.5h4v4h-4zM9.5 9.5h4v4h-4z",
        capture: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z",
        dictation: "M2 7v2M5 5v6M8 2.5v11M11 5v6M14 7v2",
        assistant: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z",
    })

    height: screen.height + 8 + details.height + 8 + hidden.height

    // An item: its picture on glass, outlined while selected; a click
    // selects it, or clears the selection, and it drags itself.
    component Tile: Rectangle {
        id: tile

        required property string modelData
        property bool half
        // On a bar along a side, where the workspaces stand in a column.
        property bool vertical

        objectName: "tile"
        implicitWidth: half ? editor.halfSize : Math.max(editor.tileSize, content.width + 12)
        implicitHeight: half ? editor.halfSize : Math.max(editor.tileSize, content.height + 12)
        color: Theme.sheen(0.14)
        border.width: editor.selected === modelData ? 2 : 0
        border.color: Theme.accent
        opacity: editor.dragged === modelData ? 0.35 : 1

        Item {
            id: content

            anchors.centerIn: parent
            width: tile.modelData === "workspaces" ? squares.width
                : text.visible ? text.width : icon.width
            height: tile.modelData === "workspaces" ? squares.height : icon.height

            Icon {
                id: icon
                visible: editor.icons[tile.modelData] !== undefined
                height: tile.half ? 9 : 14
                color: Theme.textBright
                strokeWidth: 1.5
                strokes: editor.icons[tile.modelData] ?? ""
            }
            Text {
                id: text
                anchors.centerIn: parent
                visible: tile.modelData === "clock" || tile.modelData === "language"
                text: tile.modelData === "clock" ? "09:41" : Keyboard.code || "EN"
                color: Theme.textBright
                font {
                    family: Theme.font
                    pixelSize: tile.half ? 7.5 : tile.modelData === "clock" ? 11 : 10
                    weight: Font.DemiBold
                }
            }
            Grid {
                id: squares

                visible: tile.modelData === "workspaces"
                anchors.centerIn: parent
                columns: tile.vertical ? 1 : 4
                spacing: 3

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        width: 7
                        height: 7
                        color: index === 0 ? Theme.accent : Theme.sheen(0.4)
                    }
                }
            }
        }

        TapHandler {
            onTapped: editor.selected = editor.selected === tile.modelData ? "" : tile.modelData
        }
        DragHandler {
            target: null
            cursorShape: Qt.ClosedHandCursor
            onActiveChanged: {
                if (active) {
                    editor.dragged = tile.modelData;
                    editor.selected = tile.modelData;
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
            cursorShape: Qt.PointingHandCursor
        }
    }

    Item {
        id: screen

        // Taller with a bar on a side, so that its items fit along it.
        readonly property bool side: ["Left", "Right"].includes(Settings.systemBar)
            || ["Left", "Right"].includes(Settings.dock)

        width: parent.width
        height: Math.round(width * (side ? 3 / 4 : 9 / 16))
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
                readonly property int depth: editor.tileSize + 10
                readonly property int inset: 6

                x: edge === "Right" ? screen.width - inset - width : inset
                y: edge === "Bottom" ? screen.height - inset - height
                    : vertical && otherEdge === "Top" ? depth + 2 * inset : inset
                width: vertical ? depth : screen.width - 2 * inset
                height: !vertical ? depth
                    : screen.height - 2 * inset - (otherEdge === "Top" || otherEdge === "Bottom" ? depth + inset : 0)
                color: Theme.glass(0.55)

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: Shell.zoneNames

                        // A zone: a dashed outline, solid under a dragged
                        // item, with a line where it would land.
                        Rectangle {
                            id: zone

                            required property string modelData
                            readonly property string key: `${bar.modelData} ${modelData}`
                            // Where the line stands along the bar.
                            property real mark

                            // The index the dragged item would land at, by
                            // how many tiles' middles are before the pointer,
                            // and the line after the last of them.
                            function aim(x: real, y: real) {
                                const along = bar.vertical ? y : x;
                                let count = 0;
                                let end = -1;
                                let start = -1;
                                for (const slot of inner.children)
                                    for (const tile of slot.children ?? []) {
                                        if (tile.objectName !== "tile")
                                            continue;
                                        const box = tile.mapToItem(zone, 0, 0, tile.width, tile.height);
                                        const from = bar.vertical ? box.y : box.x;
                                        const size = bar.vertical ? box.height : box.width;
                                        if (start < 0 || from < start)
                                            start = from;
                                        if (from + size / 2 < along) {
                                            count += 1;
                                            end = Math.max(end, from + size);
                                        }
                                    }
                                editor.at = count;
                                mark = end >= 0 ? end + 1.5 : start >= 0 ? start - 1.5
                                    : (bar.vertical ? inner.y : inner.x) - 1.5;
                            }

                            // A third of the bar, or as long as its items.
                            readonly property real length: (bar.vertical ? inner.implicitHeight : inner.implicitWidth) + 6
                            readonly property real share: ((bar.vertical ? bar.height : bar.width) - 20) / 3

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: bar.vertical ? 0 : length
                            Layout.minimumHeight: bar.vertical ? length : 0
                            Layout.preferredWidth: bar.vertical ? -1 : Math.max(length, share)
                            Layout.preferredHeight: bar.vertical ? Math.max(length, share) : -1
                            color: editor.over === key ? Theme.sheen(0.1) : "transparent"
                            border.width: 1
                            border.color: editor.over === key ? Theme.sheen(0.85)
                                : Theme.sheen(editor.dragged ? 0.45 : 0.16)

                            DropArea {
                                anchors.fill: parent
                                onEntered: drag => {
                                    editor.over = zone.key;
                                    zone.aim(drag.x, drag.y);
                                }
                                onPositionChanged: drag => zone.aim(drag.x, drag.y)
                                onExited: {
                                    if (editor.over === zone.key)
                                        editor.over = "";
                                }
                                onDropped: Shell.move(editor.dragged, bar.modelData, zone.modelData, editor.at)
                            }

                            GridLayout {
                                id: inner

                                x: bar.vertical ? (parent.width - width) / 2
                                    : zone.modelData === "start" ? 3 : zone.modelData === "end" ? parent.width - width - 3 : (parent.width - width) / 2
                                y: !bar.vertical ? (parent.height - height) / 2
                                    : zone.modelData === "start" ? 3 : zone.modelData === "end" ? parent.height - height - 3 : (parent.height - height) / 2
                                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                                rowSpacing: 3
                                columnSpacing: 3

                                // Slots as on the bar: two half-size items
                                // across it share one.
                                Repeater {
                                    model: Shell.slots(bar.modelData, zone.modelData)

                                    GridLayout {
                                        id: slot

                                        required property var modelData

                                        flow: bar.vertical ? GridLayout.LeftToRight : GridLayout.TopToBottom
                                        rowSpacing: 3
                                        columnSpacing: 3

                                        Repeater {
                                            model: slot.modelData

                                            Tile {
                                                half: Shell.isHalf(modelData)
                                                vertical: bar.vertical
                                                Layout.preferredWidth: implicitWidth
                                                Layout.preferredHeight: implicitHeight
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: editor.over === zone.key && editor.dragged !== ""
                                x: bar.vertical ? 3 : zone.mark - 1
                                y: bar.vertical ? zone.mark - 1 : 3
                                width: bar.vertical ? zone.width - 6 : 2
                                height: bar.vertical ? 2 : zone.height - 6
                                color: Theme.accent
                            }
                        }
                    }
                }
            }
        }
    }

    // What can be done with the selected item, or how to select one.
    Item {
        id: details

        readonly property bool shown: editor.place !== null
        readonly property bool hiddenItem: shown && editor.place.bar === ""

        y: screen.height + 8
        width: parent.width
        height: 34

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !details.shown
            text: "Click an item to move it, resize it, or hide it"
            color: Theme.textSoft
            font { family: Theme.font; pixelSize: 12 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: details.shown
            width: parent.width - actions.width - 12
            text: Shell.items[editor.selected] ?? ""
            elide: Text.ElideRight
            color: Theme.textStrong
            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
        }
        Row {
            id: actions

            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: details.shown
            spacing: 8

            // One place along the bar: left and right, or up and down.
            SettingsChoice {
                readonly property bool vertical: ["Left", "Right"].includes(Shell.edgeOf(editor.place?.bar || "system"))

                visible: !details.hiddenItem
                options: [[vertical ? "Move up" : "Move left", -1], [vertical ? "Move down" : "Move right", 1]]
                onPicked: delta => Shell.step(editor.selected, delta)
            }
            SettingsChoice {
                visible: editor.place?.bar === "dock" && Shell.canHalve(editor.selected)
                options: [["Full size", false], ["Half size", true]]
                selected: Shell.isHalf(editor.selected)
                onPicked: half => Shell.setHalf(editor.selected, half)
            }
            SettingsChoice {
                visible: details.hiddenItem || Shell.canHide(editor.selected)
                options: [details.hiddenItem ? "Show" : "Hide"]
                onPicked: {
                    if (details.hiddenItem)
                        Shell.show(editor.selected);
                    else
                        Shell.move(editor.selected, "", "", -1);
                }
            }
        }
    }

    // The hidden items: a dashed outline, solid under a dragged item that
    // can be hidden.
    Rectangle {
        id: hidden

        readonly property bool target: editor.dragged !== "" && Shell.canHide(editor.dragged)

        y: details.y + details.height + 8
        width: parent.width
        height: Math.max(46, items.height + 16)
        color: Theme.glass(editor.over === "hidden" && target ? 0.92 : 0.8)
        border.width: 1
        border.color: editor.over === "hidden" && target ? Theme.sheen(0.85)
            : Theme.sheen(target ? 0.45 : 0.16)

        DropArea {
            anchors.fill: parent
            onEntered: editor.over = "hidden"
            onExited: {
                if (editor.over === "hidden")
                    editor.over = "";
            }
            onDropped: Shell.move(editor.dragged, "", "", -1)
        }

        Text {
            anchors.centerIn: parent
            visible: Settings.hiddenItems.length === 0
            text: "Drag items here to hide them"
            color: Theme.sheen(0.6)
            font { family: Theme.font; pixelSize: 11 }
        }
        Flow {
            id: items

            x: 8
            y: 8
            width: parent.width - 16
            spacing: 4

            Repeater {
                model: Settings.hiddenItems

                Tile {}
            }
        }
    }

    // What follows the pointer while dragging.
    Rectangle {
        id: ghost

        visible: editor.dragged !== ""
        width: editor.tileSize
        height: editor.tileSize
        color: Theme.sheen(0.3)
        border.color: Theme.sheen(0.8)
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }
}
