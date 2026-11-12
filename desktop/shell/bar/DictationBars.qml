// The sound bars that show dictation listening, as in the demo; they follow what
// the microphone hears, and while it writes down what was heard, a wave runs
// through them, left to right, for as long as that takes. The assistant's button
// shows its own listening with them (QuickButton.qml).
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

Row {
    id: bars

    // The tallest bar.
    property real size: 16
    // The level, smoothed.
    property real shown: listening ? level : 0
    property bool listening: Dictation.listening
    property bool writing: Dictation.writing
    property real level: Dictation.level
    // White on the accent, as the buttons have them.
    property color color: Theme.textOnAccent
    // Where the wave is, 0 to 1, while writing.
    property real phase

    spacing: 2

    Behavior on shown { NumberAnimation { duration: 120 } }

    NumberAnimation on phase {
        running: bars.writing && bars.visible
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 1100
    }

    Repeater {
        model: [0.5, 0.8, 1, 0.7, 0.45]

        Rectangle {
            required property real modelData
            required property int index

            // While writing, each bar rises as the wave passes it.
            readonly property real wave: 0.5 + 0.5 * Math.cos(2 * Math.PI * (bars.phase - index / 5))

            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: bars.writing ? Math.max(2, bars.size * (0.25 + 0.6 * wave))
                : Math.max(2, bars.size * modelData * (0.15 + 0.85 * bars.shown))
            radius: 1
            color: bars.color
        }
    }
}
