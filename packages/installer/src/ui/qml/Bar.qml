// A thin scroll bar for the lists.
import QtQuick
import QtQuick.Templates as T

T.ScrollBar {
    id: bar

    implicitWidth: 10
    padding: 3
    minimumSize: 0.1
    visible: size < 1

    contentItem: Rectangle {
        color: bar.pressed || bar.hovered ? Theme.muted : Theme.faint
    }
}
