// A network or a device in a list (NetworkPanel.qml, WifiList.qml): its icon,
// name, and state, lit when in use, and what is at its end, such as a lock.
import QtQuick
import qs.services

Rectangle {
    id: item

    property string title
    property string detail
    property bool lit
    property bool failed
    default property alias icon: itemIcon.data
    property alias end: endHolder.data
    signal chosen

    height: 36
    color: lit ? Theme.accentSoft : itemHover.hovered ? Theme.veil(0.06) : "transparent"

    Item {
        id: itemIcon
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 11
        height: 11
    }
    Column {
        x: 34
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 30

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: item.title
            color: Theme.ink
            font { family: Theme.font; pixelSize: 12; weight: item.lit ? Font.Medium : Font.Normal }
        }
        Text {
            width: parent.width
            visible: text !== ""
            elide: Text.ElideRight
            text: item.detail
            color: item.failed ? Theme.danger : Theme.inkFaint
            font { family: Theme.font; pixelSize: 10 }
        }
    }
    Item {
        id: endHolder
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 11
    }
    TapHandler {
        onTapped: item.chosen()
    }
    HoverHandler {
        id: itemHover
        cursorShape: Qt.PointingHandCursor
    }
}
