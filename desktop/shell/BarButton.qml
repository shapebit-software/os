// A button on a bar: on the system bar, a plain square that darkens under the
// pointer and is lit while its panel is open; on the dock, a glass tile.
import QtQuick
import QtQuick.Effects

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
        color: Qt.rgba(1, 1, 1, 0.12)
        visible: !button.tile && button.open
    }
    Rectangle {
        anchors.fill: parent
        color: "#05050d"
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
        onTapped: button.clicked()
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
