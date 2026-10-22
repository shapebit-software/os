// A popover that a button on a bar opens (Popout.qml), in the demo's frame
// (PopoverFrame.qml), with its content in a column.
import QtQuick

Popout {
    id: panel

    property real panelWidth: 262
    property alias padding: frame.padding
    default property alias items: column.data
    property alias spacing: column.spacing

    PopoverFrame {
        id: frame

        Column {
            id: column
            width: panel.panelWidth - 2 * frame.padding
            spacing: 8
        }
    }
}
