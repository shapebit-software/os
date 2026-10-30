// The panel of the display's brightness (Brightness.qml), laid out as the
// sound's: the sun, the display and its brightness, and a slider.
import QtQuick

BarPanel {
    id: panel

    onVisibleChanged: {
        if (visible)
            Brightness.refresh();
    }

    Row {
        width: parent.width
        spacing: 12

        Rectangle {
            id: sun

            width: 36
            height: 36
            color: Theme.veil(0.08)

            Icon {
                anchors.centerIn: parent
                color: Theme.ink
                strokes: Brightness.icon
            }
        }

        Column {
            width: parent.width - sun.width - parent.spacing - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Item {
                width: parent.width
                height: name.height

                Text {
                    id: name
                    width: parent.width - percent.width - 8
                    elide: Text.ElideRight
                    text: "Built-in display"
                    color: Theme.inkSoft
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    id: percent
                    anchors.right: parent.right
                    anchors.baseline: name.baseline
                    text: Math.round(Brightness.value * 100) + "%"
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }

            Slider {
                width: parent.width
                value: Brightness.value
                onMoved: value => Brightness.set(value)
            }
        }
    }
}
