// What the assistant's and dictation's buttons open until the assistant
// comes: the demo's command line near the top of the screen, saying that it
// is coming.
import QtQuick
import qs.controls
import qs.services

Popout {
    id: panel

    name: "assistant"
    floating: true

    PopoverFrame {
        padding: 0

        Row {
            width: Math.min(540, panel.width - 40)
            height: 50
            leftPadding: 14
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                color: Theme.accent

                Icon {
                    anchors.centerIn: parent
                    height: 13
                    color: "#fbfbfd"
                    strokes: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "The assistant is coming in a future update"
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 15 }
            }
        }
    }
}
