// What the assistant's and dictation's buttons open until the assistant
// comes: a word that it is coming.
import QtQuick

BarPanel {
    id: panel

    name: "assistant"
    panelWidth: 260

    Row {
        spacing: 10
        padding: 4

        Icon {
            height: 18
            color: Theme.accent
            strokes: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
        }
        Column {
            spacing: 4

            Text {
                text: "Assistant"
                color: "#f0f2f4"
                font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                width: panel.panelWidth - 56
                wrapMode: Text.Wrap
                text: "Coming in a future update: ask about what is on the screen, act on it, and dictate."
                color: "#acb2b7"
                font { family: Theme.font; pixelSize: 12 }
            }
        }
    }
}
