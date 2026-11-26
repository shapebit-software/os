// The sound bars that show dictation listening, as in the demo; they follow what
// the microphone hears, and are still while it writes down what was heard. The
// assistant's button shows its own listening with them (QuickButton.qml).
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

Row {
    id: bars

    // The tallest bar.
    property real size: 16
    // The level, smoothed; half height while it writes down.
    property real shown: listening ? level : 0.35
    property bool listening: Dictation.listening
    property bool writing: Dictation.writing
    property real level: Dictation.level
    // White on the accent, as the buttons have them.
    property color color: Theme.textOnAccent

    spacing: 2

    Behavior on shown { NumberAnimation { duration: 120 } }

    Repeater {
        model: [0.5, 0.8, 1, 0.7, 0.45]

        Rectangle {
            required property real modelData

            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: Math.max(2, bars.size * modelData * (0.15 + 0.85 * bars.shown))
            radius: 1
            color: bars.color
            opacity: bars.writing ? 0.6 : 1
        }
    }
}
