// A secondary action shown as a link.
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: button

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    contentItem: Text {
        id: label
        text: button.text
        color: Theme.link
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.underline: button.hovered || button.visualFocus
    }
}
