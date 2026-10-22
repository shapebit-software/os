// The input language panel: the keyboard layouts, each with its language,
// name, and arrangement of keys; the active one's language on the accent.
pragma ComponentBehavior: Bound
import QtQuick

BarPanel {
    id: panel

    panelWidth: 240
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
            color: entryHover.hovered ? Theme.panelHover : "transparent"

            Rectangle {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 18
                color: entry.active ? Theme.accent : "transparent"
                border.color: entry.active ? "transparent" : Qt.rgba(1, 1, 1, 0.24)

                Text {
                    anchors.centerIn: parent
                    text: Keyboard.languageOf(entry.modelData)
                    color: "#f2f5f7"
                    font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 0.4 }
                }
            }
            Text {
                x: 44
                width: parent.width - x - arrangement.width - 16
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: Keyboard.nameOf(entry.modelData)
                color: "#d4d8dd"
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                id: arrangement
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Keyboard.arrangementOf(entry.modelData)
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
