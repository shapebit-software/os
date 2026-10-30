// A text field, with an optional label above it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

ColumnLayout {
    id: field

    property string label
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias echoMode: input.echoMode
    property alias validator: input.validator
    property alias maximumLength: input.maximumLength
    property alias acceptableInput: input.acceptableInput
    property alias inputMethodHints: input.inputMethodHints
    // The field that has the focus when its page opens.
    property alias initialFocus: input.focus

    // After the user typed, not after the text was set from elsewhere.
    signal edited()

    function forceActiveFocus() { input.forceActiveFocus() }

    spacing: 6

    Text {
        visible: field.label !== ""
        text: field.label
        color: Theme.muted
        font.pixelSize: 12
        font.weight: Font.Medium
    }
    T.TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: 38
        leftPadding: 12
        rightPadding: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        placeholderTextColor: Theme.faint
        selectionColor: Theme.accent
        selectedTextColor: Theme.text
        font.pixelSize: Theme.body
        onTextEdited: field.edited()

        background: Rectangle {
            color: Theme.panel
            border.color: input.activeFocus ? Theme.accent : Theme.border
        }
        // T.TextField draws no placeholder by itself.
        Text {
            x: input.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && input.preeditText === ""
            text: input.placeholderText
            color: input.placeholderTextColor
            font: input.font
        }
    }
}
