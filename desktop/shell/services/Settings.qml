// The person's settings, kept in ~/.config/desktop/settings.json, and whether
// the Settings surface is open. The shell applies them to itself through
// Theme, and to the compositor when they load and when they change.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "bars.js" as Bars

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

    // The app whose details Settings opens to, from the Apps panel.
    property var appToShow: null

    // The screen Welcome is open on, by name (Welcome.qml), and whether it
    // has been finished or skipped; until then it opens with the session, on
    // the primary display.
    property string welcomeOn
    property alias welcomed: adapter.welcomed
    // Whether Welcome last closed without having been online, so without its
    // browser and apps; the first time online after, a notification offers
    // them (SetupReminder.qml).
    property alias setupPending: adapter.setupPending
    // The system update last announced (OsUpdate.qml), so each is announced once.
    property alias updateAnnounced: adapter.updateAnnounced

    function welcome() {
        welcomeOn = primary || (Quickshell.screens[0]?.name ?? "");
    }

    function welcomeFirstTime() {
        if (!welcomed)
            welcome();
    }

    // Whether a screenshot opens for markup before it is saved (CaptureOverlay.qml).
    property alias captureMarkup: adapter.captureMarkup
    // Whether recordings take sound from the microphone.
    property alias captureMicrophone: adapter.captureMicrophone
    // Whether dictation plays its soft sounds.
    property alias dictationSounds: adapter.dictationSounds
    // Whether an application may share what was picked again without asking.
    property alias shareRemember: adapter.shareRemember
    // One of Colors.accents, or "Custom" for `accentHue`.
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
    // The buttons shown half size on the dock, two to a slot (bars.js).
    property alias halfItems: adapter.halfItems
    readonly property var defaultZones: ({
        system: { start: ["clock", "notifications"], center: ["tray"], end: ["microphone", "sound", "brightness", "network", "language", "battery", "account"] },
        dock: { start: ["apps", "workspaces"], center: [], end: ["capture", "dictation", "assistant"] },
    })
    // How the quick actions (the assistant, capture, and dictation) open:
    // "Buttons" on the bars, or "Hot corner".
    property alias quickActions: adapter.quickActions
    // The assistant (Assistant.qml): the way it was last opened, "bubbles" or
    // "panel"; whether its panel is docked beside the windows, and how wide,
    // in pixels; and whether the right edge of the screen opens the panel.
    property alias assistantLast: adapter.assistantLast
    property alias assistantDocked: adapter.assistantDocked
    property alias assistantWidth: adapter.assistantWidth
    property alias assistantEdge: adapter.assistantEdge
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
    // How the icons of the apps running in the background stand on their
    // bar (TrayIcons.qml): "Side by side", or "Stacked", one over the other
    // until the pointer is on them.
    property alias trayIcons: adapter.trayIcons
    // Do Not Disturb, which holds banners back, except critical ones, and
    // when it ends by itself, in milliseconds since the epoch, 0 for never
    // (Notifications.qml).
    property alias doNotDisturb: adapter.doNotDisturb
    property alias doNotDisturbUntil: adapter.doNotDisturbUntil
    // When the bell shows on its bar: "Always", or "With notifications",
    // only while there is anything for it to show (Notifications.present).
    property alias bell: adapter.bell
    // What each application's notifications do, for those that have sent
    // one: { key: { name, mode } } (notifications.js).
    property alias notificationApps: adapter.notificationApps
    // "12-hour" or "24-hour".
    property alias timeFormat: adapter.timeFormat
    // How dates read: "US", "UK", or "EU"; empty follows the system locale.
    property alias region: adapter.region
    readonly property string regionShown: region || (Qt.locale().name === "en_US" ? "US"
        : Qt.locale().name.startsWith("en") || Qt.locale().name === "C" ? "UK" : "EU")
    // Keyboard layout codes, such as ["us", "pl"]; empty keeps the
    // compositor's.
    property alias keyboards: adapter.keyboards
    // Mice and touchpads (Pointer.qml): whether a tap on the touchpad clicks,
    // whether scrolling moves the content with the fingers on the touchpad and
    // with the wheel on a mouse, and how fast each moves the pointer, from -1
    // to 1, 0 as libinput sets it.
    property alias tapToClick: adapter.tapToClick
    property alias touchpadNaturalScroll: adapter.touchpadNaturalScroll
    property alias touchpadSpeed: adapter.touchpadSpeed
    property alias mouseNaturalScroll: adapter.mouseNaturalScroll
    property alias mouseSpeed: adapter.mouseSpeed
    // The displays by output name (Displays.qml): scales and modes, such as
    // { "eDP-1": 1.25 } and { "eDP-1": "2560x1600@120" }; positions, such as
    // { "HDMI-A-1": "1920x0" }; and the display each one mirrors, such as
    // { "HDMI-A-1": "eDP-1" }. What is not listed is set automatically. The
    // primary display, by name; empty for the first.
    property alias scales: adapter.scales
    property alias modes: adapter.modes
    property alias positions: adapter.positions
    property alias mirrors: adapter.mirrors
    property alias primary: adapter.primary

    readonly property var gapSizes: ({ "Tight": 4, "Normal": 10, "Wide": 18 })
    readonly property int gapSize: gaps === "Custom" ? gapPixels : gapSizes[gaps] ?? 10

    // Formats for the bar and the lock screen.
    readonly property string timePattern: timeFormat === "12-hour" ? "h:mm AP" : "hh:mm"
    readonly property string datePattern: ({ "US": "ddd MMM d", "UK": "ddd d MMM", "EU": "ddd d.M." })[regionShown]
    readonly property string longDatePattern: ({ "US": "dddd, MMMM d", "UK": "dddd d MMMM", "EU": "dddd, d. MMMM" })[regionShown]

    // Whether the quick actions had the dictation button, before each
    // became an item of its own; read only by placeNewItems.
    property alias oldDictationButton: adapter.dictationButton

    // Brings saved zones up to date (bars.js).
    function placeNewItems() {
        const next = Bars.migrate(zones, hiddenItems, defaultZones, oldDictationButton);
        if (!next.changed)
            return;
        hiddenItems = next.hidden;
        zones = next.zones;
    }

    function apply() {
        placeNewItems();
        Compositor.setGaps(gapSize);
        Compositor.setDecoration(windowCorners, windowDecoration);
        Compositor.setDefaultLayout(defaultLayout);
        Pointer.apply();
        if (keyboards.length)
            Compositor.setKeyboards(keyboards);
        Displays.apply();
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
        onLoaded: {
            settings.apply();
            settings.welcomeFirstTime();
        }
        onLoadFailed: {
            settings.apply();
            settings.welcomeFirstTime();
        }

        // Quickshell does not declare the adapter's type to tooling.
        JsonAdapter { // qmllint disable unresolved-type
            id: adapter

            property string accent: "Violet"
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
            // Filled from defaultZones by placeNewItems.
            property var zones: ({})
            property list<string> hiddenItems: []
            property list<string> halfItems: ["capture", "dictation"]
            property string quickActions: "Buttons"
            property string assistantLast: "bubbles"
            property bool assistantDocked: false
            property int assistantWidth: 340
            property bool assistantEdge: true
            property string batteryPercentage: "Shown"
            property string trayIcons: "Side by side"
            property bool doNotDisturb: false
            property real doNotDisturbUntil: 0
            property string bell: "With notifications"
            property var notificationApps: ({})
            property string autolock: "5 min"
            property string screenOff: "10 min"
            property string timeFormat: "24-hour"
            property string region: ""
            property list<string> keyboards: []
            property bool tapToClick: true
            property bool touchpadNaturalScroll: true
            property real touchpadSpeed: 0
            property bool mouseNaturalScroll: false
            property real mouseSpeed: 0
            property var scales: ({})
            property var modes: ({})
            property var positions: ({})
            property var mirrors: ({})
            property string primary: ""
            property bool captureMarkup: false
            property bool captureMicrophone: false
            // Read only to bring settings saved before the quick actions
            // were separate items up to date (placeNewItems).
            property bool dictationButton: true
            property bool dictationSounds: false
            property bool shareRemember: false
            property bool welcomed: false
            property bool setupPending: false
            property string updateAnnounced: ""
        }
    }
}
