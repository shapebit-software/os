// The layout menu of a workspace: a picture of each layout, above the
// workspace's map, with an arrow to it. A click elsewhere closes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell

PopupWindow {
    id: menu

    // The map the menu belongs to; the menu sits above it.
    required property Item map
    required property int workspace
    required property real screenWidth

    readonly property int edge: 8
    // Where the menu goes along the screen: centered on the map, but at least
    // `edge` from the screen's sides. The window around it also holds the
    // shadow. The map's place is measured on opening.
    property real mapX
    readonly property real bodyX: Math.max(edge, Math.min(
        screenWidth - edge - body.width, mapX + map.width / 2 - body.width / 2))

    // The window stays on the screen, so the compositor does not move it;
    // near an edge, it cuts off part of the shadow instead.
    readonly property real windowX: Math.max(0, Math.min(screenWidth - implicitWidth, bodyX - shadow.blur))

    // The window's top left corner, relative to the map; the panel's bottom
    // is 16 above the map, the arrow reaching into that space.
    anchor.item: map
    anchor.rect.x: windowX - mapX
    anchor.rect.y: -16 - body.height - shadow.blur
    grabFocus: true

    function open() {
        mapX = map.mapToItem(null, 0, 0).x;
        visible = true;
    }
    implicitWidth: 232 + 2 * shadow.blur
    implicitHeight: body.height + 7 + 2 * shadow.blur
    color: "transparent"

    RectangularShadow {
        id: shadow
        x: body.x
        y: body.y
        width: body.width
        height: body.height
        offset.y: 14
        blur: 17
        color: Qt.rgba(0.02, 0.05, 0.07, 0.32)
    }

    Rectangle {
        id: body

        x: menu.bodyX - menu.windowX
        y: shadow.blur
        width: 232
        height: grid.height + 16
        color: Qt.rgba(0.153, 0.157, 0.188, 0.96)
        border.color: Theme.panelBorder

        Grid {
            id: grid

            x: 8
            y: 8
            columns: 4
            rowSpacing: 8
            columnSpacing: 6

            Repeater {
                model: Layouts.all

                Column {
                    id: choice

                    required property var modelData
                    readonly property bool current: Compositor.layoutOf(menu.workspace) === modelData.id

                    width: (body.width - 16 - 3 * grid.columnSpacing) / 4
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
                            menu.visible = false;
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    // The arrow to the map, an outline with the menu's color inside.
    Item {
        x: body.x + menu.mapX + menu.map.width / 2 - menu.bodyX - 7
        y: body.y + body.height - 1
        width: 14
        height: 8
        clip: true

        Rectangle {
            x: 7 - width / 2
            y: -width / 2
            width: 10
            height: 10
            rotation: 45
            color: body.color
            border.color: Theme.panelBorder
        }
    }
}
