// The layout menu of a workspace (Shell.workspace), as in the demo: a picture
// of each layout that suits its number of windows (Layouts.suits), four to a
// row and centered, beside its map with an arrow to it. A click on one sets
// it; a click elsewhere closes the menu.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import qs.bar
import qs.controls
import qs.services

Popout {
    id: menu

    readonly property int workspace: Shell.workspace
    readonly property int windows: Hyprland.workspaces.values.find(w => w.id === workspace)?.toplevels.values.length ?? 0
    readonly property string current: Compositor.layoutOf(workspace)

    // The layouts shown, the workspace's own always among them, in rows of
    // at most four.
    readonly property var choices: Layouts.all.filter(l => l.id === current || Layouts.suits(l.id, windows))
    readonly property var rows: {
        const rows = [];
        for (let i = 0; i < choices.length; i += 4)
            rows.push(choices.slice(i, i + 4));
        return rows;
    }
    readonly property real rowWidth: Math.min(4, choices.length) * 68 - 12

    name: "layout"
    margin: 16

    PopoverFrame {
        Column {
            spacing: 10

            Repeater {
                model: menu.rows

                Row {
                    id: row

                    required property var modelData

                    x: (menu.rowWidth - width) / 2
                    spacing: 12

                    Repeater {
                        model: row.modelData

                        Column {
                            id: choice

                            required property var modelData
                            readonly property bool current: menu.current === modelData.id
                            // The picture's columns: [width, [[height, active, split?], ...]],
                            // a split cell being two side by side.
                            readonly property var picture: modelData.glyph ?? modelData.picture

                            width: 56
                            spacing: 5

                            Rectangle {
                                width: parent.width
                                height: 30
                                color: Theme.veil(0.1)
                                border.color: choice.current ? Theme.accent : "transparent"

                                Row {
                                    id: picture

                                    x: 3
                                    y: 3
                                    width: parent.width - 6
                                    height: parent.height - 6
                                    spacing: 3

                                    Repeater {
                                        model: choice.picture

                                        Column {
                                            id: column

                                            required property var modelData

                                            width: (picture.width - picture.spacing * (choice.picture.length - 1))
                                                * modelData[0] / choice.picture.reduce((sum, c) => sum + c[0], 0)
                                            height: picture.height
                                            spacing: 3

                                            Repeater {
                                                model: column.modelData[1]

                                                Row {
                                                    id: cell

                                                    required property var modelData
                                                    readonly property color color: modelData[1]
                                                        ? (choice.current ? Theme.accent : Theme.oklch(0.42, 0.07, 290, 0.72))
                                                        : Theme.oklch(0.42, 0.07, 290, 0.36)

                                                    width: column.width
                                                    height: (column.height - column.spacing * (column.modelData[1].length - 1))
                                                        * modelData[0] / column.modelData[1].reduce((sum, c) => sum + c[0], 0)
                                                    spacing: 3

                                                    Repeater {
                                                        model: cell.modelData[2] ? 2 : 1

                                                        Rectangle {
                                                            width: cell.modelData[2] ? (cell.width - 3) / 2 : cell.width
                                                            height: cell.height
                                                            color: cell.color
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: choice.modelData.name
                                color: choice.current ? Theme.accent : Theme.oklch(0.45, 0.07, 290)
                                font { family: Theme.font; pixelSize: 10; weight: Font.Medium }
                            }

                            TapHandler {
                                onTapped: {
                                    Compositor.setLayout(menu.workspace, choice.modelData.id);
                                    menu.dismissed();
                                }
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }
}
