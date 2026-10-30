// The frame of a popover (Popout.qml), as in the demo: light glass from top
// to bottom, a thin ring, and soft shadows; the content inside, padded.
import QtQuick
import QtQuick.Effects
import qs.services

Item {
    id: frame

    default property alias content: holder.data
    property real padding: 10

    implicitWidth: holder.childrenRect.width + 2 * padding
    implicitHeight: holder.childrenRect.height + 2 * padding
    width: implicitWidth
    height: implicitHeight

    RectangularShadow {
        anchors.fill: parent
        offset.y: 6
        blur: 16
        color: Theme.oklch(0.15, 0.05, 285, 0.1)
    }
    RectangularShadow {
        anchors.fill: parent
        offset.y: 1
        blur: 2
        color: Theme.oklch(0.15, 0.05, 285, 0.06)
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.rounded ? 9 : 0
        border.color: Theme.popoverRing
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.popoverTop }
            GradientStop { position: 1; color: Theme.popoverBottom }
        }

        // The light along the top edge.
        Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: 1
            color: "white"
        }
    }

    Item {
        id: holder
        x: frame.padding
        y: frame.padding
        width: childrenRect.width
        height: childrenRect.height
    }
}
