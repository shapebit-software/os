// The Apps button: four dots, the last one dimmer. On the dock it is a glass
// tile, brighter while Apps is open; on the system bar, a plain button.
pragma ComponentBehavior: Bound
import QtQuick

BarButton {
    id: button

    readonly property real dot: tile ? 9 : 5

    Grid {
        columns: 2
        spacing: button.tile ? 4 : 2.5

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: button.dot
                height: button.dot
                radius: button.dot / 2
                color: "#fbfcfd"
                opacity: index === 3 ? 0.55 : 1
            }
        }
    }
}
