// A small button in a pill (ButtonPill.qml): "strong", filled with the accent,
// for the one the person most likely wants.
import QtQuick
import qs.services

Rectangle {
    id: choice

    property alias text: label.text
    property bool strong
    signal activated

    width: label.width + 16
    height: 22
    color: strong ? Theme.accent : choiceHover.hovered ? Theme.veil(0.12) : Theme.veil(0.07)

    Text {
        id: label
        anchors.centerIn: parent
        color: choice.strong ? Theme.textOnAccent : Theme.ink
        font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
    }
    TapHandler {
        onTapped: choice.activated()
    }
    HoverHandler {
        id: choiceHover
        cursorShape: Qt.PointingHandCursor
    }
}
