// The Apps button: four dots, the last one dimmer. On the dock it is a glass
// tile, brighter while Apps is open; on the system bar, a plain button.
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

BarButton {
    id: button

    // Large dots on a full-size dock tile.
    readonly property bool large: tile && size >= 40
    readonly property real dot: large ? 9 : 5

    Grid {
        columns: 2
        spacing: button.large ? 4 : 2.5

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: button.dot
                height: button.dot
                radius: button.dot / 2
                color: Theme.textOnAccent
                opacity: index === 3 ? 0.55 : 1
            }
        }
    }
}
