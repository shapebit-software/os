// A square button in the bar; it darkens under the pointer.
import QtQuick

Item {
    id: button

    default property alias content: holder.data

    implicitWidth: Math.max(30, holder.childrenRect.width + 12)
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        color: "#05050d"
        opacity: hover.hovered ? 0.14 : 0
    }

    Item {
        id: holder
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
