// Options side by side in Settings, the selected one raised.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Rectangle {
    id: choice

    // Each option is a label, or [label, value].
    property var options: []
    property var selected
    signal picked(var value)

    width: row.width + 4
    height: row.height + 4
    color: "#eceff1"

    Row {
        id: row

        x: 2
        y: 2
        spacing: 2

        Repeater {
            model: choice.options

            Item {
                id: option

                required property var modelData
                readonly property string label: Array.isArray(modelData) ? modelData[0] : modelData
                readonly property var value: Array.isArray(modelData) ? modelData[1] : modelData
                readonly property bool current: choice.selected === value

                width: text.width + 20
                height: 26

                RectangularShadow {
                    visible: option.current
                    anchors.fill: parent
                    offset.y: 1
                    blur: 2
                    color: Qt.rgba(0, 0, 0, 0.14)
                }
                Rectangle {
                    anchors.fill: parent
                    color: option.current ? "white" : "transparent"
                }
                Text {
                    id: text
                    anchors.centerIn: parent
                    text: option.label
                    color: option.current ? "#181b1e" : "#54595e"
                    font { family: Theme.font; pixelSize: 12 }
                }

                TapHandler {
                    onTapped: choice.picked(option.value)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
