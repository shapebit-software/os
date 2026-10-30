// A drop-down list in Settings, for choices too long to show side by side.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: select

    // Each option is [label, value].
    property var options: []
    property var selected
    signal picked(var value)

    model: options.map(o => o[0])
    currentIndex: options.findIndex(o => o[1] === selected)
    onActivated: index => picked(options[index][1])
    implicitWidth: Math.max(120, contentItem.implicitWidth + 40)
    implicitHeight: 30
    font { family: Theme.font; pixelSize: 12 }

    background: Rectangle {
        color: "white"
        border.color: select.hovered ? "#b9bec3" : "#d1d5d8"
    }
    contentItem: Text {
        leftPadding: 10
        verticalAlignment: Text.AlignVCenter
        text: select.displayText
        color: "#1d2022"
        font: select.font
    }
    indicator: Icon {
        x: select.width - width - 10
        y: (select.height - height) / 2
        height: 10
        gridWidth: 10
        gridHeight: 10
        strokeWidth: 1.3
        color: "#44484d"
        strokes: "M2 3.5l3 3 3-3"
    }
}
