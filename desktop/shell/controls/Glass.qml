// The glass of the dock's items: a light pane over the wallpaper with a soft
// shadow, lighter while `lit`.
import QtQuick
import QtQuick.Effects
import qs.services

Item {
    id: glass

    property bool lit
    property alias color: pane.color

    RectangularShadow {
        anchors.fill: parent
        offset.y: 6
        blur: 16
        radius: pane.radius
        color: Qt.rgba(0.01, 0.01, 0.04, 0.3)
    }
    Rectangle {
        id: pane
        anchors.fill: parent
        radius: Theme.rounded ? 2.5 : 0
        color: Qt.rgba(1, 1, 1, glass.lit ? 0.3 : 0.14)
    }
}
