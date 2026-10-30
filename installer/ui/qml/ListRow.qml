// One row of a list: highlighted when it is the chosen one. Rows are not
// Tab stops unless a list makes them so: a long list would trap the focus.
import QtQuick
import QtQuick.Templates as T

T.ItemDelegate {
    id: row

    property bool chosen: false

    implicitHeight: 34
    leftPadding: 12
    rightPadding: 12
    opacity: enabled ? 1 : 0.45

    background: Rectangle {
        color: row.chosen ? Theme.selected : row.hovered || row.visualFocus ? Qt.lighter(Theme.panel, 1.25) : "transparent"
    }
}
