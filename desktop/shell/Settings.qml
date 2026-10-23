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

    // Whether a screenshot opens for markup before it is saved (CaptureOverlay.qml).
    property alias captureMarkup: adapter.captureMarkup
    // Whether recordings take sound from the microphone.
    property alias captureMicrophone: adapter.captureMicrophone
    // One of `accents`, or "Custom" for `accentHue`.
    property alias accent: adapter.accent
    property alias accentHue: adapter.accentHue
    // One of Wallpaper.presets, or "Image" for `wallpaperImage`, a path.
    property alias wallpaper: adapter.wallpaper
    property alias wallpaperImage: adapter.wallpaperImage
    // "Straight" or "Rounded".
    property alias windowCorners: adapter.windowCorners
    // "None", "Hairline", "Shadow", or "Soft".
    property alias windowDecoration: adapter.windowDecoration
    // One of `gapSizes`, or "Custom" for `gapPixels`.
    property alias gaps: adapter.gaps
    property alias gapPixels: adapter.gapPixels
    // The layout of new workspaces, by id (Layouts.qml).
    property alias defaultLayout: adapter.defaultLayout
    // The bars: where each one is ("Top", "Bottom", "Left", or "Right"),
    // what fills them ("None", "Glass", or "Solid"), and which items each
    // zone holds, in order: { bar: { start, center, end } } with bars "system"
    // and "dock" (Shell.qml).
    property alias systemBar: adapter.systemBar
    property alias dock: adapter.dock
    property alias barBackground: adapter.barBackground
    property alias zones: adapter.zones
    // The items on neither bar, by id, which only Settings > Shell shows.
    property alias hiddenItems: adapter.hiddenItems
    readonly property var defaultZones: ({
        system: { start: ["clock"], center: [], end: ["notifications", "microphone", "sound", "brightness", "network", "language", "battery", "account"] },
        dock: { start: ["apps", "workspaces"], center: [], end: ["quick"] },
    })
    // How the quick actions open: "Buttons" in the corner, or "Hot corner".
    property alias quickActions: adapter.quickActions
    // When to lock after the computer has been idle: "1 min", "5 min", or
    // "Never"; lockAfter is that in seconds, 0 for never.
    property alias autolock: adapter.autolock
    readonly property var lockTimes: ({ "1 min": 60, "5 min": 300, "Never": 0 })
    readonly property int lockAfter: lockTimes[autolock] ?? 300
    // When to turn the screens off after the computer has been idle: "2 min",
    // "10 min", or "Never"; screenOffAfter is that in seconds, 0 for never.
    property alias screenOff: adapter.screenOff
    readonly property var screenOffTimes: ({ "2 min": 120, "10 min": 600, "Never": 0 })
    readonly property int screenOffAfter: screenOffTimes[screenOff] ?? 600
    // Whether the battery's percentage shows inside its icon on the bar:
    // "Shown" or "Hidden".
    property alias batteryPercentage: adapter.batteryPercentage
    // Whether new notifications show as banners; critical ones always do.
    property alias doNotDisturb: adapter.doNotDisturb
    // "12-hour" or "24-hour".
    property alias timeFormat: adapter.timeFormat
    // How dates read: "US", "UK", or "EU"; empty follows the system locale.
    property alias region: adapter.region
    readonly property string regionShown: region || (Qt.locale().name === "en_US" ? "US"
        : Qt.locale().name.startsWith("en") || Qt.locale().name === "C" ? "UK" : "EU")
    // Keyboard layout codes, such as ["us", "pl"]; empty keeps the
    // compositor's.
    property alias keyboards: adapter.keyboards
    // Display scales and modes by output name, such as { "eDP-1": 1.25 } and
    // { "eDP-1": "2560x1600@120" }; outputs not listed are set automatically.
    property alias scales: adapter.scales
    property alias modes: adapter.modes

    // The accents' hues, as in the demo (Theme.accent).
    readonly property var accents: ({ "Cyan": 215, "Indigo": 265, "Green": 150, "Amber": 45, "Plum": 335 })
    readonly property int accentHueShown: accent === "Custom" ? accentHue : accents[accent] ?? 215
    readonly property var gapSizes: ({ "Tight": 4, "Normal": 10, "Wide": 18 })
    readonly property int gapSize: gaps === "Custom" ? gapPixels : gapSizes[gaps] ?? 10

    // Formats for the bar and the lock screen.
    readonly property string timePattern: timeFormat === "12-hour" ? "h:mm AP" : "hh:mm"
    readonly property string datePattern: ({ "US": "ddd MMM d", "UK": "ddd d MMM", "EU": "ddd d.M." })[regionShown]
    readonly property string longDatePattern: ({ "US": "dddd, MMMM d", "UK": "dddd d MMMM", "EU": "dddd, d. MMMM" })[regionShown]

    function setScale(output: string, scale: real) {
        scales = Object.assign({}, scales, { [output]: scale });
        Compositor.setMonitor(output, modes[output] ?? "preferred", scale);
    }

    function setMode(output: string, mode: string) {
        modes = Object.assign({}, modes, { [output]: mode });
        Compositor.setMonitor(output, mode, scales[output] ?? "auto");
    }

    // Items that the saved zones lack, such as ones added since, go where they
    // are by default: before the next item that follows them there. Hidden
    // ones stay off the bars.
    function placeNewItems() {
        const next = JSON.parse(JSON.stringify(zones));
        const placed = new Set(hiddenItems);
        for (const bar of Object.values(next))
            for (const ids of Object.values(bar))
                ids.forEach(id => placed.add(id));
        let changed = false;
        for (const [bar, barZones] of Object.entries(defaultZones)) {
            for (const [zone, ids] of Object.entries(barZones)) {
                ids.forEach((id, index) => {
                    if (placed.has(id))
                        return;
                    const list = next[bar][zone];
                    const following = ids.slice(index + 1).find(other => list.includes(other));
                    list.splice(following ? list.indexOf(following) : list.length, 0, id);
                    changed = true;
                });
            }
        }
        if (changed)
            zones = next;
    }

    function apply() {
        placeNewItems();
        Compositor.setGaps(gapSize);
        Compositor.setDecoration(windowCorners, windowDecoration);
        Compositor.setDefaultLayout(defaultLayout);
        if (keyboards.length)
            Compositor.setKeyboards(keyboards);
        for (const output of new Set([...Object.keys(scales), ...Object.keys(modes)]))
            Compositor.setMonitor(output, modes[output] ?? "preferred", scales[output] ?? "auto");
    }

    onGapSizeChanged: Compositor.setGaps(gapSize)
    onWindowCornersChanged: Compositor.setDecoration(windowCorners, windowDecoration)
    onWindowDecorationChanged: Compositor.setDecoration(windowCorners, windowDecoration)
    onDefaultLayoutChanged: Compositor.setDefaultLayout(defaultLayout)
    onKeyboardsChanged: {
        if (keyboards.length) {
            Compositor.setKeyboards(keyboards);
            Keyboard.refresh();
        }
    }

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
            property int accentHue: 25
            property string wallpaper: "Dusk"
            property string wallpaperImage: ""
            property string windowCorners: "Straight"
            property string windowDecoration: "Hairline"
            property string gaps: "Normal"
            property int gapPixels: 10
            property string defaultLayout: "columns"
            property string systemBar: "Top"
            property string dock: "Bottom"
            property string barBackground: "None"
            property var zones: settings.defaultZones
            property list<string> hiddenItems: []
            property string quickActions: "Buttons"
            property string batteryPercentage: "Shown"
            property bool doNotDisturb: false
            property string autolock: "5 min"
            property string screenOff: "10 min"
            property string timeFormat: "24-hour"
            property string region: ""
            property list<string> keyboards: []
            property var scales: ({})
            property var modes: ({})
            property bool captureMarkup: false
            property bool captureMicrophone: false
        }
    }
}
