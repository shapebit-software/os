// A short label beside an item of a bar while the pointer rests on it, on
// the side away from the bar, in the panels' light glass.
import QtQuick
import Quickshell
import qs.services

PopupWindow {
    id: tip

    required property Item target
    // The edge of the bar the item is on.
    required property string edge
    property alias text: label.text
    // Whether the pointer is on the item; the label follows after a moment.
    property bool hovered
    readonly property real gap: 6
    readonly property int away: ({ Top: Edges.Bottom, Bottom: Edges.Top, Left: Edges.Right, Right: Edges.Left })[edge]
        ?? Edges.Bottom

    visible: hovered && delay.done && text !== ""
    color: "transparent"
    implicitWidth: label.implicitWidth + 20 + (edge === "Left" || edge === "Right" ? gap : 0)
    implicitHeight: label.implicitHeight + 12 + (edge === "Top" || edge === "Bottom" ? gap : 0)
    anchor.item: target
    // Quickshell does not declare the edges' type to tooling.
    anchor.edges: away // qmllint disable missing-type
    anchor.gravity: away // qmllint disable missing-type

    onHoveredChanged: delay.done = false

    Timer {
        id: delay

        property bool done

        running: tip.hovered && !done
        interval: 500
        onTriggered: done = true
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: tip.edge === "Top" ? tip.gap : 0
        anchors.bottomMargin: tip.edge === "Bottom" ? tip.gap : 0
        anchors.leftMargin: tip.edge === "Left" ? tip.gap : 0
        anchors.rightMargin: tip.edge === "Right" ? tip.gap : 0
        color: Theme.popoverTop
        border.color: Theme.popoverRing

        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.ink
            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
        }
    }
}
