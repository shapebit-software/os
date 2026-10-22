// The layout menu of a workspace (Shell.workspace): a picture of each layout
// that suits its number of windows (Layouts.suits), beside its map, with an
// arrow to it. A click on one sets it; a click elsewhere closes the menu.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland

Popout {
    id: menu

    readonly property int workspace: Shell.workspace
    readonly property int windows: Hyprland.workspaces.values.find(w => w.id === workspace)?.toplevels.values.length ?? 0

    // The layouts shown, the workspace's own always among them, at most four
    // to a row.
    readonly property var choices: Layouts.all.filter(l =>
        l.id === Compositor.layoutOf(workspace) || Layouts.suits(l.id, windows))
    readonly property int columns: Math.min(4, choices.length)
    readonly property real choiceWidth: 49.5

    name: "layout"
    margin: 16
    arrow: true
    arrowColor: frame.color
    arrowBorder: frame.border.color

    RectangularShadow {
        anchors.fill: frame
        offset.y: 14
        blur: 17
        color: Qt.rgba(0.02, 0.05, 0.07, 0.32)
    }

    Rectangle {
        id: frame

        width: grid.width + 16
        height: grid.height + 16
        color: Qt.rgba(0.153, 0.157, 0.188, 0.96)
        border.color: Theme.panelBorder

        Grid {
            id: grid

            x: 8
            y: 8
            columns: menu.columns
            rowSpacing: 8
            columnSpacing: 6

            Repeater {
                model: menu.choices

                Column {
                    id: choice

                    required property var modelData
                    readonly property bool current: Compositor.layoutOf(menu.workspace) === modelData.id

                    width: menu.choiceWidth
                    spacing: 5

                    // The picture: the layout's cells, the active one lit.
                    Rectangle {
                        width: parent.width
                        height: 28
                        color: "#232a36"
                        border.color: choice.current ? Theme.accent : "transparent"

                        Row {
                            id: picture

                            x: 3
                            y: 3
                            width: parent.width - 6
                            height: parent.height - 6
                            spacing: 3

                            Repeater {
                                model: choice.modelData.picture

                                Column {
                                    id: column

                                    required property var modelData
                                    readonly property real total: choice.modelData.picture
                                        .reduce((sum, c) => sum + c[0], 0)

                                    width: (picture.width - picture.spacing * (choice.modelData.picture.length - 1))
                                        * modelData[0] / total
                                    height: picture.height
                                    spacing: 3

                                    Repeater {
                                        model: column.modelData[1]

                                        Rectangle {
                                            required property var modelData

                                            width: column.width
                                            height: (column.height - column.spacing * (column.modelData[1].length - 1))
                                                * modelData[0] / column.modelData[1].reduce((sum, c) => sum + c[0], 0)
                                            color: !modelData[1] ? "#a3a6aa"
                                                : choice.current ? Theme.accent : "#e2e5e9"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: choice.modelData.name
                        color: choice.current ? Theme.accent : "#a8adb2"
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
