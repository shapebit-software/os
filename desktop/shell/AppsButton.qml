// The Apps button at the start of the strip: glass with four dots. It is
// brighter while Apps is open.
import QtQuick
import QtQuick.Effects

Item {
    id: button

    property bool open
    signal clicked

    width: Theme.stripHeight
    height: Theme.stripHeight

    layer.enabled: hover.hovered
    layer.effect: MultiEffect { brightness: 0.15 }

    RectangularShadow {
        anchors.fill: parent
        offset.y: 6
        blur: 16
        color: Qt.rgba(0.01, 0.01, 0.04, 0.3)
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, button.open ? 0.3 : 0.14)
    }

    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 4

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: 9
                height: 9
                radius: 4.5
                color: "#fbfcfd"
                opacity: index === 3 ? 0.55 : 1
            }
        }
    }

    TapHandler {
        onTapped: button.clicked()
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
