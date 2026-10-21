// The input language panel: the keyboard layouts, the active one marked.
pragma ComponentBehavior: Bound
import QtQuick

BarPanel {
    id: panel

    panelWidth: 220
    spacing: 1

    Repeater {
        model: Keyboard.layouts

        Rectangle {
            id: entry

            required property string modelData
            required property int index
            readonly property bool active: index === Keyboard.active

            width: panel.panelWidth - 20
            height: 32
            color: entryHover.hovered ? Theme.panelHover : active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Text {
                x: 8
                width: 22
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.toUpperCase()
                color: "#e7ecf0"
                font { family: Theme.font; pixelSize: 11; weight: Font.Bold; letterSpacing: 0.4 }
            }
            Text {
                x: 40
                width: parent.width - x - 24
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: Keyboard.nameOf(entry.modelData)
                color: "#d4d8dd"
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.active
                text: "●"
                color: "#94999e"
                font { family: Theme.mono; pixelSize: 10 }
            }

            TapHandler {
                onTapped: {
                    Keyboard.select(entry.index);
                    panel.dismissed();
                }
            }
            HoverHandler {
                id: entryHover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
