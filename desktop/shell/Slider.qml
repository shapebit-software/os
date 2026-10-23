// A slider, as in the demo's panels: the track, the value in the accent, and a
// knob. Dragging or clicking reports the new value, from 0 to 1.
import QtQuick

Item {
    id: slider

    property real value
    signal moved(real value)

    height: 4

    function report(x: real) {
        moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.veil(0.07)
    }
    Rectangle {
        width: parent.width * Math.min(1, slider.value)
        height: parent.height
        radius: 2
        color: Theme.accent
    }
    Rectangle {
        x: parent.width * Math.min(1, slider.value) - width / 2
        y: -6
        width: 16
        height: 16
        radius: 8
        color: "#fbfbfd"
        border.color: Theme.veil(0.12)
    }
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.report(mouse.x)
        onPositionChanged: mouse => slider.report(mouse.x)
    }
}
