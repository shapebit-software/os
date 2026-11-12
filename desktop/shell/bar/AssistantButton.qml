// A small icon button of the assistant's panel and bubbles, such as New or
// Open in panel, with what it does in a tip beside it: below, or above with
// `tipAbove`; lined up with its right edge, or its left with `tipLeft`.
import QtQuick
import qs.controls
import qs.services

Rectangle {
    id: button

    property string strokes
    property string tip
    property bool on
    property bool tipLeft
    property bool tipAbove
    signal activated

    width: 28
    height: 28
    color: on ? Theme.veil(0.12) : hover.hovered ? Theme.veil(0.07) : "transparent"

    Icon {
        anchors.centerIn: parent
        height: 13
        color: button.on || hover.hovered ? Theme.ink : Theme.inkFaint
        strokeWidth: 1.3
        strokes: button.strokes
    }
    TapHandler {
        onTapped: button.activated()
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    Rectangle {
        visible: hover.hovered && button.tip !== ""
        z: 10
        x: button.tipLeft ? 0 : button.width - width
        y: button.tipAbove ? -height - 4 : button.height + 4
        width: tipLabel.width + 14
        height: 22
        color: Theme.ink

        Text {
            id: tipLabel
            anchors.centerIn: parent
            text: button.tip
            color: Theme.textOnAccent
            font { family: Theme.font; pixelSize: 11 }
        }
    }
}
