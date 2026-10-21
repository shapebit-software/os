// The person's settings, kept in ~/.config/desktop/settings.json, and whether
// the Settings surface is open. The shell applies them to itself through
// Theme, and to the compositor when they load and when they change.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: settings

    readonly property string directory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desktop"

    // The screen Settings is open on, by name, and its section.
    property string openOn
    property string section: "account"

    function open(screen: string, section: string) {
        settings.section = section;
        openOn = screen;
    }

    property alias accent: adapter.accent
    property alias gaps: adapter.gaps
    property alias reduceTransparency: adapter.reduceTransparency
    // When to lock after the computer has been idle: "1 min", "5 min", or
    // "Never"; lockAfter is that in seconds, 0 for never.
    property alias autolock: adapter.autolock
    readonly property var lockTimes: ({ "1 min": 60, "5 min": 300, "Never": 0 })
    readonly property int lockAfter: lockTimes[autolock] ?? 300
    // Display scales by output name, such as { "eDP-1": 1.25 }; outputs not
    // listed are scaled automatically.
    property alias scales: adapter.scales

    readonly property var accents: ({
        "Cyan": "#007890",
        "Indigo": "#4966a8",
        "Green": "#317a45",
        "Amber": "#9c522e",
        "Plum": "#8f4e82",
    })
    readonly property var gapSizes: ({ "Tight": 4, "Normal": 10, "Wide": 16 })

    function setScale(output: string, scale: real) {
        scales = Object.assign({}, scales, { [output]: scale });
        Compositor.setScale(output, scale);
    }

    readonly property int gapSize: gapSizes[gaps] ?? 10

    function apply() {
        Compositor.setGaps(gapSize);
        for (const output in scales)
            Compositor.setScale(output, scales[output]);
    }

    onGapSizeChanged: Compositor.setGaps(gapSize)

    // The first save needs the directory.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", directory])

    FileView {
        path: settings.directory + "/settings.json"
        blockLoading: true
        // Edits to the file take effect at once, and changes here are saved.
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: settings.apply()
        onLoadFailed: settings.apply()

        // Quickshell does not declare the adapter's type to tooling.
        JsonAdapter { // qmllint disable unresolved-type
            id: adapter

            property string accent: "Cyan"
            property string gaps: "Normal"
            property bool reduceTransparency: false
            property string autolock: "5 min"
            property var scales: ({})
        }
    }
}
