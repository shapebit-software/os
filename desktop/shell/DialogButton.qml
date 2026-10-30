// A button of the portals' dialogs (FileChooserDialog.qml,
// QuestionDialog.qml), as the account panel's: filled with the accent for
// the action itself.
import QtQuick

Rectangle {
    id: button

    property alias text: label.text
    property bool strong
    signal activated

    width: Math.max(96, label.width + 32)
    height: 34
    color: strong ? Theme.accent : Theme.veil(buttonHover.hovered ? 0.1 : 0.05)

    Text {
        id: label
        anchors.centerIn: parent
        color: button.strong ? "white" : Theme.ink
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
    }

    TapHandler {
        enabled: button.enabled
        onTapped: button.activated()
    }
    HoverHandler {
        id: buttonHover
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
