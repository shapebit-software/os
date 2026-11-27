pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The assistant's settings in the desktop, kept in
// ~/.config/desktop/assistant.json (SettingsFile.qml); its service keeps its
// own, such as the model, in ~/.config/assistant/settings.json.
Singleton {
    // The way it was last opened, "bubbles" or "panel"; whether its panel is
    // docked beside the windows, and how wide, in pixels; whether the right
    // edge of the screen opens the panel; and whether a soft sound says a
    // spoken request was taken.
    property alias last: adapter.last
    property alias docked: adapter.docked
    property alias width: adapter.width
    property alias edge: adapter.edge
    property alias sounds: adapter.sounds

    SettingsFile {
        name: "assistant"

        // Quickshell does not declare the adapter's type to tooling.
        JsonAdapter { // qmllint disable unresolved-type
            id: adapter

            property string last: "bubbles"
            property bool docked: false
            property int width: 340
            property bool edge: true
            property bool sounds: true
        }
    }
}
