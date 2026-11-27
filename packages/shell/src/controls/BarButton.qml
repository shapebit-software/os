// A button on a bar: on the system bar, a plain square that darkens under the
// pointer and is lit while its panel is open; on the dock, a glass tile.
import QtQuick
import QtQuick.Effects
import qs.controls
import qs.services

Item {
    id: button

    default property alias content: holder.data
    property bool open
    property bool tile
    property int size: 30
    // A color over the whole button, such as red while recording.
    property color fill: "transparent"
    readonly property bool hovered: hover.hovered
    signal clicked
    signal rightClicked
    // Pressed and kept down, and let go after that; no click follows.
    signal held
    signal letGo

    // Wide enough for the widest content shown, such as the input language.
    implicitWidth: Math.max(size, ...holder.children.filter(c => c.visible).map(c => c.width + 12))
    implicitHeight: size

    Glass {
        anchors.fill: parent
        visible: button.tile
        lit: button.open
        layer.enabled: hover.hovered
        layer.effect: MultiEffect { brightness: 0.15 }
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.sheen(0.12)
        visible: !button.tile && button.open
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.shade(1)
        visible: !button.tile
        opacity: hover.hovered ? 0.14 : 0
    }
    Rectangle {
        anchors.fill: parent
        color: button.fill
    }

    // The content, each piece centered, whatever else is hidden beside it.
    Item {
        id: holder
        anchors.fill: parent
    }
    Component.onCompleted: {
        for (const child of holder.children)
            child.anchors.centerIn = holder;
    }

    TapHandler {
        property bool holding

        longPressThreshold: 0.4
        onTapped: button.clicked()
        onLongPressed: {
            holding = true;
            button.held();
        }
        onPressedChanged: {
            if (!pressed && holding) {
                holding = false;
                button.letGo();
            }
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: button.rightClicked()
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
