// The sound bars that show dictation listening, as in the demo; they follow what
// the microphone hears, and are still while it writes down what was heard.
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

Row {
    id: bars

    // The tallest bar.
    property real size: 16
    // The level, smoothed; half height while it writes down.
    property real shown: Dictation.listening ? Dictation.level : 0.35

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
            color: Theme.textOnAccent
            opacity: Dictation.writing ? 0.6 : 1
        }
    }
}
