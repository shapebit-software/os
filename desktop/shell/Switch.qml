// A switch, as in the demo: the accent with the knob right when on.
import QtQuick

Rectangle {
    id: control

    property bool on
    property color offColor: Theme.veil(0.12)
    signal toggled

    width: 30
    height: 17
    radius: 9
    color: on ? Theme.accent : offColor

    Rectangle {
        x: control.on ? 15 : 2
        y: 2
        width: 13
        height: 13
        radius: 7
        color: "#fbfbfd"

        Behavior on x { NumberAnimation { duration: 120 } }
    }
    TapHandler {
        onTapped: control.toggled()
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
