// A square check box. The caller places the text beside it.
import QtQuick
import QtQuick.Templates as T

T.CheckBox {
    id: box

    implicitWidth: 16
    implicitHeight: 16
    opacity: enabled ? 1 : 0.4

    indicator: Rectangle {
        anchors.fill: parent
        color: box.checked ? Theme.accent : "transparent"
        border.color: box.checked ? Theme.accent : box.visualFocus ? Theme.text : Theme.muted
        Text {
            anchors.centerIn: parent
            visible: box.checked
            text: "✓"
            color: Theme.text
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }
}
