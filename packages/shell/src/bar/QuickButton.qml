// A quick action's button on a bar (ShellItem.qml), shown with
// Settings.quickActions "Buttons": the button to dictate; a feature's, such
// as the assistant's or capture's, is its own (Features.qml). Each is an item
// of its own, and on the dock it can be half size, two to a slot (Shell.qml).
//
// While dictating (Dictation.qml), the dictation
// button is filled with the accent and its icon says the state: sound bars that
// follow the voice while listening, a turning arc while it writes the words down,
// red when something is wrong, and then briefly where the words went, a
// check or a clipboard, which pops in; a click stops, a right click discards, or
// with nothing under way, starts a dictation that only copies. It has no tooltip
// of its own, only what the person must know, such as a missing microphone.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

BarButton {
    id: button

    // The ShellBar; qmllint does not take a ShellBar for itself inside
    // ShellBar.qml, where items are made.
    required property var bar
    // "dictation".
    required property string kind
    property bool half

    readonly property string screenName: bar.modelData?.name ?? ""
    readonly property bool dictate: kind === "dictation"
    readonly property bool dictating: dictate && (Dictation.active || Dictation.result !== null)
    readonly property bool hearing: dictate && Dictation.listening && !Dictation.quiet
    readonly property bool wrong: dictate && (Dictation.state === "failed" || Dictation.notice.startsWith("No m") || Dictation.notice.startsWith("Mic"))

    tile: bar.dock
    fill: wrong ? Theme.dangerFill : dictating ? Theme.accent : "transparent"
    onClicked: {
        if (dictate)
            Dictation.toggle(false);
    }
    onRightClicked: {
        if (dictate)
            Dictation.secondary();
    }

    // Dictation's Tidy up shows by this button (TidyPill.qml).
    Connections {
        target: button.dictate ? Dictation : null

        function onPillAsked(screen: string) {
            if (screen === button.screenName && button.visible && !Dictation.pillAt)
                Dictation.pillAt = button.bar.place(button);
        }
    }

    Tooltip {
        target: button
        edge: button.bar.edge
        hovered: button.visible && button.dictate && Dictation.telling
        text: Dictation.status
    }
    DictationBars {
        visible: button.hearing
        size: button.half ? 12 : 16
        // Narrow enough on a half-size button that it keeps its size.
        spacing: button.half ? 1 : 2
    }
    // Dictation writes the words down: a turning arc.
    Icon {
        id: arc
        visible: button.dictate && Dictation.writing
        height: button.half ? 14 : 18
        color: Theme.textOnAccent
        strokeWidth: 1.8
        strokes: "M8 2.5a5.5 5.5 0 1 1-5.5 5.5"

        RotationAnimation on rotation {
            running: arc.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
    }
    Icon {
        id: icon

        visible: !button.hearing && !(button.dictate && Dictation.writing)
        height: button.half ? 14 : 18
        color: Theme.textBright
        strokeWidth: 1.5
        strokes: Dictation.icon
    }

    // Where the dictated words went pops in.
    NumberAnimation {
        id: pop

        target: icon
        property: "scale"
        from: 0.4
        to: 1
        duration: 260
        easing.type: Easing.OutBack
    }
    Connections {
        target: button.dictate ? Dictation : null

        function onResultChanged() {
            if (Dictation.result)
                pop.restart();
        }
    }
}
