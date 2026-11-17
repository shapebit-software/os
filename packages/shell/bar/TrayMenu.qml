// The menu of a background app's icon (TrayIcons.qml), as the application
// gives it: entries with their icons, check marks, and separators. An entry
// with a menu of its own opens that in place, with a row that leads back.
pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.controls
import qs.services
import "../services/tray.js" as Logic

BarPanel {
    id: menu

    // The entries entered, each with a menu of its own, the open one last,
    // and what holds each one's menu open; the application's own menu stays
    // open below them, or it would let its entries go.
    property var path: []
    property var entered: []
    readonly property QsMenuOpener current: entered.length ? entered[entered.length - 1] : opener
    readonly property int rowWidth: panelWidth - 2 * padding
    // Whether any entry has an icon or a mark, which all then leave room for.
    readonly property bool marks: current.children.values
        .some(e => e.icon !== "" || e.buttonType !== QsMenuButtonType.None)

    name: "tray"
    panelWidth: 240
    padding: 6
    spacing: 0

    onVisibleChanged: path = []

    QsMenuOpener {
        id: opener
        // Quickshell does not declare the menu's type to tooling.
        menu: menu.visible ? Tray.menuOf?.menu ?? null : null // qmllint disable unresolved-type
    }
    Instantiator {
        model: ScriptModel {
            values: menu.path
        }
        onObjectAdded: (index, object) => menu.entered = [...menu.entered, object]
        onObjectRemoved: (index, object) => menu.entered = menu.entered.filter(o => o !== object)

        QsMenuOpener {
            required property QsMenuEntry modelData
            menu: modelData
        }
    }

    component MenuRow: Rectangle {
        id: row

        property alias text: label.text
        property bool submenu
        // What stands before the label: an icon, or a check mark.
        property string icon
        property bool checked
        property bool back
        signal picked

        width: menu.rowWidth
        height: 30
        color: rowHover.hovered && enabled ? Theme.veil(0.07) : "transparent"
        opacity: enabled ? 1 : 0.45

        IconImage {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.icon !== "" && !row.checked
            implicitSize: 16
            source: row.icon
        }
        Icon {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.checked || row.back
            height: 14
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            color: row.back ? Theme.inkSoft : Theme.accent
            strokes: row.back ? "M9.6 3.6L5.2 8l4.4 4.4" : "M3.5 8.4l3 3 6-6.6"
        }
        Text {
            id: label

            x: menu.marks || menu.path.length > 0 ? 32 : 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (row.submenu ? 26 : 10)
            elide: Text.ElideRight
            color: row.back ? Theme.inkSoft : Theme.ink
            font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
        }
        Icon {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: row.submenu
            height: 14
            strokeWidth: 1.6
            color: Theme.inkFaint
            strokes: "M6.4 3.6L10.8 8l-4.4 4.4"
        }

        TapHandler {
            onTapped: row.picked()
        }
        HoverHandler {
            id: rowHover
            cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    MenuRow {
        visible: menu.path.length > 0
        back: true
        text: "Back"
        onPicked: menu.path = menu.path.slice(0, -1)
    }

    Repeater {
        model: menu.current.children

        Loader {
            id: entry

            required property QsMenuEntry modelData

            sourceComponent: modelData.isSeparator ? separator : item

            Component {
                id: separator

                Item {
                    width: menu.rowWidth
                    height: 9

                    Rectangle {
                        x: 8
                        y: 4
                        width: parent.width - 16
                        height: 1
                        color: Theme.veil(0.12)
                    }
                }
            }
            Component {
                id: item

                MenuRow {
                    text: Logic.label(entry.modelData.text)
                    enabled: entry.modelData.enabled
                    submenu: entry.modelData.hasChildren
                    icon: entry.modelData.icon
                    checked: entry.modelData.buttonType !== QsMenuButtonType.None
                        && entry.modelData.checkState === Qt.Checked
                    onPicked: {
                        if (entry.modelData.hasChildren) {
                            menu.path = [...menu.path, entry.modelData];
                            return;
                        }
                        entry.modelData.triggered();
                        menu.dismissed();
                    }
                }
            }
        }
    }
}
