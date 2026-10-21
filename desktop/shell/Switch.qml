// An on and off switch: the accent with the knob right when on.
import QtQuick

Rectangle {
    id: control

    property bool checked
    signal toggled

    width: 30
    height: 17
    radius: 9
    color: checked ? Theme.accent : "#2c2e31"

    Rectangle {
        x: control.checked ? control.width - width - 2 : 2
        y: 2
        width: 13
        height: 13
        radius: 7
        color: "#121212"
    }

    TapHandler {
        onTapped: control.toggled()
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
