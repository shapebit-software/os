// A square button in the bar; it darkens under the pointer and is lit while
// its panel is open.
import QtQuick

Item {
    id: button

    default property alias content: holder.data
    property bool open
    signal clicked
    signal rightClicked

    implicitWidth: Math.max(30, holder.childrenRect.width + 12)
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.12)
        visible: button.open
    }
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

    TapHandler {
        onTapped: button.clicked()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: button.rightClicked()
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
