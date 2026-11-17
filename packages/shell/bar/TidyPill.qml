// Dictation's Tidy up (Dictation.qml), by its button (ButtonPill.qml): offered
// for a few seconds after dictated text went into a field, as Super+T is until
// the next dictation; then what it does, and how it ended, for a moment. A
// click on "Tidy up" has the assistant's model tidy the text in its place.
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

ButtonPill {
    id: pill

    readonly property string status: Dictation.tidying === "asking" ? "Tidying up…"
        : Dictation.tidying === "writing" ? "Writing it in…" : Dictation.tidyNotice

    name: "tidy"
    at: Dictation.pillAt
    shown: Dictation.tidyOffered || status !== ""
    // It stays while the pointer is on it.
    onHoveredChanged: {
        if (hovered && Dictation.tidyOffered)
            Dictation.offerTidy();
    }

    Row {
        spacing: 8

        Text {
            visible: pill.status !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 300)
            text: pill.status
            color: Theme.inkSoft
            wrapMode: Text.Wrap
            font { family: Theme.font; pixelSize: 12 }
        }
        PillChoice {
            visible: Dictation.tidyOffered && Dictation.tidying === ""
            anchors.verticalCenter: parent.verticalCenter
            text: "Tidy up"
            strong: true
            onActivated: Dictation.tidy()
        }
    }
}
