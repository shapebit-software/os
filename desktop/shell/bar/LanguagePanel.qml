// The input language panel: the keyboard layouts, each with its language on
// a chip, its name, and its arrangement of keys; the active one's chip is on
// the accent, with a check mark.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.controls
import qs.services

BarPanel {
    id: panel

    panelWidth: 236
    padding: 8
    spacing: 2

    Repeater {
        model: Keyboard.layouts

        Rectangle {
            id: entry

            required property string modelData
            required property int index
            readonly property bool active: index === Keyboard.active

            width: panel.panelWidth - 2 * panel.padding
            height: 40
            color: entryHover.hovered ? Theme.veil(0.07) : "transparent"

            Rectangle {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 22
                color: entry.active ? Theme.accent : "transparent"
                border.color: entry.active ? "transparent" : Theme.veil(0.2)

                Text {
                    anchors.centerIn: parent
                    text: Keyboard.languageOf(entry.modelData)
                    color: entry.active ? "#fbfbfd" : Theme.inkSoft
                    font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 0.6 }
                }
            }
            Column {
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 30
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Keyboard.nameOf(entry.modelData)
                    color: Theme.ink
                    font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                }
                Text {
                    visible: text !== ""
                    text: Keyboard.arrangementOf(entry.modelData)
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }
            Icon {
                visible: entry.active
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 14
                strokeWidth: 1.8
                capStyle: ShapePath.RoundCap
                color: Theme.accent
                strokes: "M3.5 8.4l3 3 6-6.6"
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
