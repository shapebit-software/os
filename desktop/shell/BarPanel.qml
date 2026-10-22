// A panel that a button on a bar opens (Popout.qml): a dark body with its
// content in a column.
import QtQuick
import QtQuick.Effects

Popout {
    id: panel

    property real panelWidth: 262
    default property alias items: column.data
    property alias spacing: column.spacing

    RectangularShadow {
        anchors.fill: frame
        offset.y: 14
        blur: 17
        color: Qt.rgba(0.02, 0.05, 0.07, 0.32)
    }

    Rectangle {
        id: frame

        width: panel.panelWidth
        height: column.implicitHeight + 20
        color: Theme.panel
        border.color: Theme.panelBorder

        Column {
            id: column
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8
        }
    }
}
