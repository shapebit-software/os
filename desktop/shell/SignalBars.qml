// The bars of a Wi-Fi signal, as many lit as it is strong, of three.
pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: bars

    property real strength: 1
    property color color: Theme.inkFaint

    spacing: 1.5

    Repeater {
        model: [4, 7, 11]

        Rectangle {
            required property int modelData
            required property int index
            anchors.bottom: parent.bottom
            width: 2
            height: modelData
            color: bars.color
            opacity: bars.strength > index / 3 ? 1 : 0.3
        }
    }
}
