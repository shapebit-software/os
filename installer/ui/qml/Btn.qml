// A button: "primary" for the way forward, "secondary" for the way back,
// "danger" for the step that erases the disk.
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: button

    property string kind: "primary"
    readonly property color fill: kind === "danger" ? Theme.danger : Theme.accent

    implicitWidth: label.implicitWidth + (kind === "secondary" ? 40 : 52)
    implicitHeight: 40
    opacity: enabled ? 1 : 0.4

    contentItem: Text {
        id: label
        text: button.text
        color: Theme.text
        font.pixelSize: Theme.body
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: button.kind === "secondary" ? (button.hovered ? Theme.panel : "transparent")
            : button.down ? Qt.darker(button.fill, 1.15) : button.hovered ? Qt.lighter(button.fill, 1.1) : button.fill
        border.color: button.visualFocus ? Theme.text : button.kind === "secondary" ? Theme.border : "transparent"
    }
}
