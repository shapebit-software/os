// Settings, over the windows of the screen it was opened on and between its
// bars, inset like a window so the desktop shows around it: sections
// in groups on the left with a search across all of them, and the open
// section's settings on the right (SettingsRow.qml). Some settings lead to a
// page of their own, such as choosing a picture. Escape, the close button, or
// a click beside it closes it; on a page, Escape goes back.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import qs.controls
import qs.services
import qs.wallpaper

PanelWindow {
    id: window

    required property ShellScreen modelData

    // The display that Settings > Display changes (Displays.qml): the one
    // picked in the arrangement, or else this screen's.
    property string displayName
    readonly property var display: Displays.byName(displayName) ?? Displays.byName(modelData?.name ?? "")
    readonly property var modes: display?.modes ?? []
    readonly property string size: display ? `${display.width}x${display.height}` : ""
    readonly property int rate: display?.rate ?? 0
    property string timeZone
    property bool automaticTime
    property list<string> timeZones
    // The system's language, such as "en_GB.UTF-8", and those installed.
    property string systemLocale
    property list<string> locales

    // A locale by its own language's name, such as "polski (Polska)".
    function localeName(locale: string): string {
        const qt = Qt.locale(locale.split(".")[0]);
        return qt.nativeTerritoryName ? `${qt.nativeLanguageName} (${qt.nativeTerritoryName})` : qt.nativeLanguageName || locale;
    }

    // Changes the system's language through localectl, which asks for an
    // administrator; then reads it again.
    function localectl(args: list<string>) {
        localeSetter.command = ["localectl", ...args];
        localeSetter.running = true;
    }

    // Changes the time settings through timedatectl, which asks for an
    // administrator (Authorization.qml); then reads them again.
    function timedate(args: list<string>) {
        timeSetter.command = ["timedatectl", ...args];
        timeSetter.running = true;
    }

    // The open page, or none: "picture", "wallpaper", "keyboards",
    // "password", "wifi", "bluetooth", or "app".
    property string page

    // Each section: { id, name, icon, rows }, rows as in SettingsRow.qml.
    readonly property var sections: [
        { id: "account", name: "Account", icon: "M5.2 5.6a2.8 2.8 0 1 0 5.6 0a2.8 2.8 0 1 0-5.6 0zM2.6 14.2a5.4 5.4 0 0 1 10.8 0", rows: [
            { label: "Picture", detail: "Shown on the lock screen and in the system menu", kind: "picture",
              open: () => page = "picture" },
            { label: "Name", detail: "Shown on the lock screen and in the system menu", value: Account.displayName },
            { label: "Password", detail: "Unlocks the session and the home", value: "Change",
              open: () => page = "password" },
            { label: "Lock automatically", detail: "After the screen has been idle", kind: "choice",
              options: Object.keys(Settings.lockTimes), selected: Settings.autolock,
              select: o => Settings.autolock = o },
            { label: "Turn screen off", detail: "After the screen has been idle", kind: "choice",
              options: Object.keys(Settings.screenOffTimes), selected: Settings.screenOff,
              select: o => Settings.screenOff = o },
            { label: "Welcome", detail: "The network, the browser, and the ways around", value: "Open",
              open: () => {
                  Settings.openOn = "";
                  Settings.welcomeOn = window.modelData.name;
              } },
        ] },
        // The models and the downloads of the one on this computer, how it
        // loads, what it can do, and what it may do unasked; then where it shows.
        { id: "assistant", name: "Assistant", icon: Assistant.icon, rows: [
            { label: "Models", detail: "Gemma on this computer",
              value: Assistant.model?.name ?? "None", open: () => page = "assistant-models" },
            ...assistantExtras.map(e => ({ label: e.name, detail: e.detail, kind: "extra", extra: e })),
            ...(Assistant.model?.where === "local" ? [{ label: "Load the model", kind: "choice",
              detail: Assistant.loading === "used"
                  ? `When first asked, which takes some seconds; it frees about ${modelMemory} of memory after 10 minutes unused`
                  : `Shortly after sign-in, to answer at once; it keeps about ${modelMemory} of memory in use`,
              options: ["After sign-in", "When used"], selected: Assistant.loading === "used" ? "When used" : "After sign-in",
              select: o => Assistant.setLoading(o === "When used" ? "used" : "ready") }] : []),
            { label: "Sound when it hears you", detail: "A soft sound as soon as it takes what you said, before the answer comes",
              kind: "toggle", on: Settings.assistantSounds, toggle: () => Settings.assistantSounds = !Settings.assistantSounds },
            ...(Dictation.available ? [{ label: "Load the speech model", kind: "choice",
              detail: Settings.speechModel === "ready"
                  ? "For dictation and voice: shortly after sign-in, to hear at once; it keeps about 1.1 GB of memory in use"
                  : "For dictation and voice: when first used, which takes about two seconds; it frees about 1.1 GB of memory once unused",
              options: ["After sign-in", "When used"], selected: Settings.speechModel === "ready" ? "After sign-in" : "When used",
              select: o => Settings.speechModel = o === "When used" ? "used" : "ready" }] : []),
            ...(Dictation.available && Settings.speechModel === "used" ? [{ label: "Free the speech model", kind: "choice",
              detail: "After this long without dictation or voice",
              options: ["5 min", "10 min", "20 min", "1 hour"],
              selected: Settings.speechModelMinutes === 60 ? "1 hour" : `${Settings.speechModelMinutes} min`,
              select: o => Settings.speechModelMinutes = o === "1 hour" ? 60 : parseInt(o) }] : []),
            { label: "Skills and tools", detail: "What the assistant knows how to do, and skills of your own",
              value: `${Assistant.skills.length} ${Assistant.skills.length === 1 ? "skill" : "skills"} · ${Assistant.tools.length} tools`,
              open: () => page = "assistant-skills" },
            { label: "Permissions", detail: "What it may do without asking, and the activity log",
              value: `${Assistant.grants.length} of ${Object.keys(Assistant.groups).length} allowed`,
              open: () => page = "assistant-permissions" },
            { label: "Panel beside the windows", detail: "The assistant's panel takes its own room at the right, and windows retile beside it",
              kind: "toggle", on: Settings.assistantDocked, toggle: () => Settings.assistantDocked = !Settings.assistantDocked },
            { label: "Right edge opens the panel", detail: "Push the pointer against the middle of the screen's right edge",
              kind: "toggle", on: Settings.assistantEdge, toggle: () => Settings.assistantEdge = !Settings.assistantEdge },
        ] },
        { id: "language", name: "Language", icon: "M2 8a6 6 0 1 0 12 0a6 6 0 1 0-12 0zM2 8h12M8 2c-2.2 2.4-2.2 9.6 0 12M8 2c2.2 2.4 2.2 9.6 0 12", rows: [
            { label: "System language", detail: "For the whole computer, from the next sign-in; needs an administrator",
              kind: "select", options: locales.map(l => [window.localeName(l), l]).sort((a, b) => a[0].localeCompare(b[0])),
              selected: systemLocale, select: l => window.localectl(["set-locale", "LANG=" + l]) },
            { label: "Region format", detail: "Dates in the bar and on the lock screen", kind: "choice",
              options: ["US", "UK", "EU"], selected: Settings.regionShown, select: o => Settings.region = o },
            { label: "Keyboards", value: "Manage", open: () => page = "keyboards",
              detail: `${(Settings.keyboards.length ? Settings.keyboards : Keyboard.layouts).map(k => Keyboard.nameOf(k)).join(", ")} · switch with Super+Space` },
        ] },
        { id: "time", name: "Time", icon: "M2 8a6 6 0 1 0 12 0a6 6 0 1 0-12 0zM8 4.5V8l2.4 1.6", rows: [
            { label: "Time zone", detail: "For the whole computer; needs an administrator", kind: "select",
              options: timeZones.map(z => [z.replace(/_/g, " "), z]), selected: timeZone,
              select: z => window.timedate(["set-timezone", z]) },
            { label: "Set time automatically", detail: "From the network", kind: "toggle", on: automaticTime,
              toggle: () => window.timedate(["set-ntp", String(!window.automaticTime)]) },
            { label: "Time format", detail: "Shown in the top bar and lock screen", kind: "choice",
              options: ["12-hour", "24-hour"], selected: Settings.timeFormat, select: o => Settings.timeFormat = o },
        ] },
        { id: "desktop", name: "Desktop", icon: "M1.8 2.8h12.4v10.4H1.8zM1.8 11l3.6-3.4 3 2.6 2.2-1.8 3.6 2.8M9.6 5.8a1 1 0 1 0 2 0a1 1 0 1 0-2 0z", rows: [
            { label: "Accent color", detail: "Focus, selection and toggles", kind: "swatches" },
            { label: "Wallpaper", detail: "Choose a preset or your own image", kind: "wallpapers",
              open: () => page = "wallpaper" },
        ] },
        { id: "shell", name: "Shell", icon: "M1.8 2.8h12.4v10.4H1.8zM1.8 5.4h12.4M4.6 10.6h6.8", rows: [
            { label: "Layout", detail: "Drag an item to move it, or click it to reorder, resize, or hide it", kind: "shell" },
            { label: "System bar", detail: "Clock and status icons", kind: "choice",
              options: Shell.edges, selected: Settings.systemBar, select: o => Shell.place("system", o) },
            { label: "Dock", detail: "Apps, workspaces and quick actions", kind: "choice",
              options: Shell.edges, selected: Settings.dock, select: o => Shell.place("dock", o) },
            { label: "Bar background", detail: "Fill behind the bars", kind: "choice",
              options: ["None", "Glass", "Solid"], selected: Settings.barBackground,
              select: o => Settings.barBackground = o },
            { label: "Quick actions", detail: "Assistant, capture and dictation: buttons on the bars, or a hot corner", kind: "choice",
              options: ["Buttons", "Hot corner"], selected: Settings.quickActions,
              select: o => Settings.quickActions = o },
            { label: "Dictation sounds", detail: "A soft sound when dictation starts and stops", kind: "toggle",
              on: Settings.dictationSounds, toggle: () => Settings.dictationSounds = !Settings.dictationSounds },
            { label: "Background apps", detail: "Their icons on the bar: side by side, or stacked until the pointer is on them", kind: "choice",
              options: ["Side by side", "Stacked"], selected: Settings.trayIcons,
              select: o => Settings.trayIcons = o },
            ...(Battery.available ? [{ label: "Battery percentage", detail: "Inside the battery icon in the system bar", kind: "choice",
              options: ["Shown", "Hidden"], selected: Settings.batteryPercentage,
              select: o => Settings.batteryPercentage = o }] : []),
        ] },
        // Do Not Disturb, and how long it stays on, and each application that has sent a notification (Notifications.qml).
        { id: "notifications", name: "Notifications", icon: "M4 10V6.2a4 4 0 0 1 8 0V10l1.2 1.4H2.8zM6.6 12.4a1.5 1.5 0 0 0 2.8 0", rows: [
            { label: "Do Not Disturb", kind: "toggle", on: Settings.doNotDisturb,
              detail: !Settings.doNotDisturb ? "Holds banners back, except critical ones; they stay in the notifications"
                  : Settings.doNotDisturbUntil > 0 ? `On until ${Qt.formatTime(new Date(Settings.doNotDisturbUntil), Settings.timePattern)}`
                  : "On until turned off",
              toggle: () => Notifications.setQuiet(Settings.doNotDisturb ? "" : "Until turned off") },
            ...(Settings.doNotDisturb ? [{ label: "Stays on", detail: "Do Not Disturb turns off by itself after the time chosen",
              kind: "choice", options: Notifications.quietChoices,
              selected: Settings.doNotDisturbUntil > 0 ? "" : "Until turned off",
              select: c => Notifications.setQuiet(c) }] : []),
            { label: "Bell", detail: "On its bar always, or only while there are notifications or downloads, or Do Not Disturb is on",
              kind: "choice", options: ["Always", "With notifications"], selected: Settings.bell,
              select: o => Settings.bell = o },
            ...(Notifications.apps.length ? Notifications.apps.map(a => ({ label: a.name, kind: "choice",
              detail: a.mode === "Off" ? "Its notifications are dropped"
                  : a.mode === "Center only" ? "No banners; kept in the notifications" : "Banners, and kept in the notifications",
              options: Notifications.modes, selected: a.mode, select: m => Notifications.setMode(a.key, m, a.name) }))
              : [{ label: "Apps", detail: "Each app shows here once it has sent a notification", kind: "info" }]),
        ] },
        { id: "windows", name: "Windows", icon: "M1.8 2.8h7v10.4h-7zM10.4 2.8h3.8v4.4h-3.8zM10.4 8.8h3.8v4.4h-3.8z", rows: [
            { label: "Corners", detail: "Shape of tiled windows", kind: "choice",
              options: ["Straight", "Rounded"], selected: Settings.windowCorners,
              select: o => Settings.windowCorners = o },
            { label: "Decoration", detail: "Edge treatment around windows", kind: "choice",
              options: ["None", "Hairline", "Shadow", "Soft"], selected: Settings.windowDecoration,
              select: o => Settings.windowDecoration = o },
            { label: "Gaps", detail: "Space between tiled windows", kind: "gaps" },
            { label: "Default layout", detail: "Used for new workspaces", kind: "select",
              options: ["columns", "tabs", "rows"].map(id => [Layouts.byId(id).name, id]),
              selected: Settings.defaultLayout, select: o => Settings.defaultLayout = o },
        ] },
        { id: "display", name: "Display", icon: "M1.8 2.6h12.4v8.4H1.8zM5.5 13.8h5M8 11v2.8", rows: [
            ...(Displays.all.length > 1 ? [{ label: "Arrangement", kind: "displays",
              detail: "Drag the displays to where they stand; click one to change it below",
              selected: display?.name ?? "", select: n => window.displayName = n }] : []),
            ...(Displays.arranged.length > 1 ? [{ label: "Primary display", kind: "select",
              detail: "Where the session starts, with its first workspace and the pointer",
              options: Displays.arranged.map(d => [d.label, d.name]), selected: Displays.primary,
              select: n => Displays.setPrimary(n) }] : []),
            // Mirrors are not in the arrangement; they are picked here.
            ...(Displays.all.length > 1 ? [{ label: "Display", kind: "select",
              detail: "The one the settings below change",
              options: Displays.all.map(d => [d.label, d.name]), selected: display?.name ?? "",
              select: n => window.displayName = n }] : []),
            { label: "Resolution", detail: display?.label ?? "", kind: "select",
              options: [...new Set(modes.map(m => m.size))].map(s => [s.replace("x", " × "), s]),
              selected: size,
              select: s => Displays.setMode(display.name, `${s}@${Math.max(...modes.filter(m => m.size === s).map(m => m.rate))}`) },
            ...(display?.mirrorOf ? [] : [{ label: "Scale", detail: "Size of text and interface", kind: "choice",
              options: ["100%", "125%", "150%", "200%"],
              selected: `${Math.round((display?.scale ?? 1) * 100)}%`,
              select: o => Displays.setScale(display.name, parseInt(o) / 100) }]),
            { label: "Refresh rate", detail: display?.label ?? "", kind: "select",
              options: [...new Set(modes.filter(m => m.size === size).map(m => m.rate))].map(r => [`${r} Hz`, r]),
              selected: rate, select: r => Displays.setMode(display.name, `${size}@${r}`) },
            // Settings goes along to the display mirrored, since its own
            // screen goes away.
            ...(Displays.all.length > 1 && display ? [{ label: "Mirror", kind: "select",
              detail: `Show on ${display.label} what another display shows`,
              options: [["Off", ""], ...Displays.arranged.filter(d => d.name !== display.name).map(d => [d.label, d.name])],
              selected: display.mirrorOf, select: n => {
                  const name = display.name;
                  Displays.setMirror(name, n);
                  if (n && Settings.openOn === name)
                      Settings.openOn = n;
              } }] : []),
        ] },
        { id: "pointing", name: "Mouse", icon: "M4.5 6a3.5 3.5 0 0 1 7 0v4a3.5 3.5 0 0 1-7 0zM8 2.5v3", rows: [
            ...(Pointer.touchpads.length ? [
                { label: "Tap to click", detail: "A tap on the touchpad clicks", kind: "toggle",
                  on: Settings.tapToClick, toggle: () => Settings.tapToClick = !Settings.tapToClick },
                { label: "Touchpad natural scrolling", detail: "The content moves with the fingers", kind: "toggle",
                  on: Settings.touchpadNaturalScroll, toggle: () => Settings.touchpadNaturalScroll = !Settings.touchpadNaturalScroll },
                { label: "Touchpad speed", detail: "How fast the pointer moves", kind: "slider",
                  value: (Settings.touchpadSpeed + 1) / 2, move: v => Settings.touchpadSpeed = Math.round((v * 2 - 1) * 20) / 20 },
            ] : []),
            { label: "Mouse natural scrolling", detail: "The content moves with the wheel", kind: "toggle",
              on: Settings.mouseNaturalScroll, toggle: () => Settings.mouseNaturalScroll = !Settings.mouseNaturalScroll },
            { label: "Mouse speed", detail: "How fast the pointer moves", kind: "slider",
              value: (Settings.mouseSpeed + 1) / 2, move: v => Settings.mouseSpeed = Math.round((v * 2 - 1) * 20) / 20 },
        ] },
        { id: "network", name: "Network", icon: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z", rows: [
            ...(Connectivity.wired.length ? [{ label: "Ethernet", detail: "Wired connection",
              value: Connectivity.wiredConnected ? "Connected" : "Disconnected" }] : []),
            ...(Connectivity.wifi ? [{ label: "Wi-Fi", detail: Connectivity.wifiDetail, kind: "toggle",
              on: Networking.wifiEnabled, toggle: () => Connectivity.toggleWifi() }] : []),
            ...(Connectivity.wifi && Networking.wifiEnabled ? [{ label: "Wi-Fi networks",
              detail: "Join, disconnect, or forget networks", value: "Manage", open: () => page = "wifi" }] : []),
            ...(Connectivity.adapter ? [{ label: "Bluetooth", detail: Connectivity.bluetoothDetail, kind: "toggle",
              on: Connectivity.adapter.enabled, toggle: () => Connectivity.toggleBluetooth() }] : []),
            ...(Connectivity.adapter?.enabled ? [{ label: "Bluetooth devices",
              detail: "Pair, connect, or forget devices", value: "Manage", open: () => page = "bluetooth" }] : []),
        ] },
        // Its page is its own (AppsPage.qml); the row is for the search.
        { id: "apps", name: "Apps", own: true, icon: "M2.4 2.4h4.4v4.4H2.4zM9.2 2.4h4.4v4.4H9.2zM2.4 9.2h4.4v4.4H2.4zM9.2 9.2h4.4v4.4H9.2z", rows: [
            { label: "Apps", detail: "Find, install, and remove apps", value: "Open",
              open: () => window.show("apps") },
        ] },
        // Its page is its own (DownloadsPage.qml); the row is for the search.
        { id: "downloads", name: "Downloads", own: true, icon: "M8 2v8.4M4.6 7l3.4 3.4L11.4 7M2.6 13.4h10.8", rows: [
            { label: "Downloads", detail: "What is downloading and installing: apps, browsers, and optional downloads",
              value: "Open", open: () => window.show("downloads") },
        ] },
        { id: "updates", name: "Updates", icon: "M13 8a5 5 0 1 1-1.5-3.6M11.8 1.8v2.8H9", rows: [
            { label: "System", detail: Account.system, value: OsUpdate.describe(OsUpdate.version) },
            { label: "System updates", detail: OsUpdate.stateText,
              value: OsUpdate.checking ? "Checking…" : "Check now",
              open: () => OsUpdate.checking || OsUpdate.checkNow() },
            { label: "Apps", detail: "Updated automatically every day", kind: "info" },
        ] },
        // What the system and its downloads are made of, and under which licenses.
        { id: "licenses", name: "Licenses", icon: "M4 1.8h5.6l2.8 2.8v9.6H4zM9.4 1.8v3h3M6 8h4.4M6 10.6h4.4", rows: [
            { label: "ShapeBit OS", detail: "PolyForm Shield License 1.0.0. The ShapeBit name and logo are not licensed for reuse",
              value: "Read", open: () => window.openLink("https://polyformproject.org/licenses/shield/1.0.0") },
            { label: "Fedora Linux and the other programs", detail: "Each under its own license, such as the GPL, the LGPL, MIT, or Apache 2.0",
              value: "Open", open: () => window.openLink("file:///usr/share/licenses") },
            { label: "Sources", detail: `Each version's sources are published next to it: ghcr.io/shapebit-software/os:${OsUpdate.version}-sources`,
              value: "Read", open: () => window.openLink("https://shapebit.software/docs/license/#sources") },
            ...[].concat(...Extras.list.map(e => (e.credits ?? []).map(c => ({ label: c.work,
              detail: `${c.license} · by ${c.by}${c.changes ? `, ${c.changes}` : ""} · ${e.name}, ${e.installed ? "downloaded" : "not downloaded"}`,
              value: "Source", open: () => window.openLink(c.url) })))),
        ] },
        { id: "sound", name: "Sound", icon: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z", rows: [
            { label: "Output", detail: Audio.output?.description ?? "No device",
              value: `${Math.round((Audio.output?.audio?.volume ?? 0) * 100)}%` },
            { label: "Input", detail: Audio.input?.description ?? "No device",
              value: `${Math.round((Audio.input?.audio?.volume ?? 0) * 100)}%` },
        ] },
    ]
    // The sections in the sidebar's groups.
    readonly property var groups: [
        ["account", "assistant", "language", "time"],
        ["desktop", "shell", "notifications", "windows"],
        ["display", "pointing", "network", "sound"],
        ["apps", "downloads", "updates", "licenses"],
    ]
    // The extras of Settings > Assistant: the model's first, then its vision
    // projector, then the rest, such as dictation's, which voice needs.
    readonly property var assistantExtras: {
        const model = Assistant.model?.extra ?? "";
        const rank = e => e.id === model ? 0 : e.id === `${model}-vision` ? 1 : 2;
        return Extras.list.slice().sort((a, b) => rank(a) - rank(b));
    }
    // The memory a local model holds while loaded: its files, read into
    // memory, and room for the conversation.
    readonly property string modelMemory: {
        const extra = Extras.list.find(e => e.id === Assistant.model?.extra);
        const vision = Extras.list.find(e => e.id === `${Assistant.model?.extra}-vision` && e.installed);
        return `${(((extra?.bytes ?? 0) + (vision?.bytes ?? 0) + 1300000000) / 1e9).toFixed(1)} GB`;
    }

    // Pages that are rows, as a section's.
    readonly property var pageRows: ({
        "assistant-permissions": [
            // What the assistant may do without asking; the rest asks every time.
            ...Object.keys(Assistant.groups).map(g => ({ label: Assistant.groups[g], kind: "toggle",
              detail: Assistant.grants.includes(g) ? "Without asking" : "Asks first, on its card",
              on: Assistant.grants.includes(g), toggle: () => Assistant.grants.includes(g) ? Assistant.revoke(g) : Assistant.grant(g) })),
            { label: "Activity log", detail: "What the assistant did and what it was allowed, kept on this computer", kind: "choice",
              options: ["7 days", "30 days", "90 days", "Always"],
              selected: Assistant.retention === 0 ? "Always" : `${Assistant.retention} days`,
              select: o => Assistant.setRetention(o === "Always" ? 0 : parseInt(o)) },
            { label: "Clear the activity log", detail: "Conversations stay; delete them from the assistant's list", value: "Clear",
              open: () => Assistant.clearHistory() },
        ],
    })

    // The pages: their title, and the section they belong to.
    readonly property var pages: ({
        "assistant-models": ["Models", "assistant"],
        "assistant-skills": ["Skills and tools", "assistant"],
        "assistant-permissions": ["Permissions", "assistant"],
        "picture": ["Choose a picture", "account"],
        "wallpaper": ["Choose a wallpaper", "desktop"],
        "keyboards": ["Keyboards", "language"],
        "password": ["Change password", "account"],
        "wifi": ["Wi-Fi networks", "network"],
        "bluetooth": ["Bluetooth devices", "network"],
        "app": ["App details", "apps"],
    })

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var section: sections.find(s => s.id === Settings.section) ?? sections[0]
    readonly property var rows: query
        ? [].concat(...sections.map(s => s.rows), ...Object.values(pageRows)).filter(r => (r.label + " " + r.detail).toLowerCase().includes(query))
        : page ? pageRows[page] ?? [] : section.own ? [] : section.rows

    function close() {
        Settings.openOn = "";
    }

    // A web page or a folder, in its application; Settings closes, as it covers
    // the windows.
    function openLink(url: string) {
        close();
        Qt.openUrlExternally(url);
    }

    function show(id: string) {
        search.text = "";
        page = "";
        Settings.section = id;
    }

    screen: modelData
    visible: Settings.openOn === (modelData?.name ?? "")
    // Over everything, even a fullscreen window. The bars show through,
    // dimmed, and stay in use: only the space between them takes input.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "settings"
    // It covers the windows, so taking the keyboard holds back nothing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: workArea }

    // Something else wanted: a panel off the bars, which would open under
    // Settings, or a new window, such as an app from the dock.
    Connections {
        target: Shell

        function onPanelChanged() {
            if (Shell.panel)
                window.close();
        }
    }
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name === "openwindow")
                window.close();
        }
    }

    onVisibleChanged: {
        search.text = "";
        page = "";
        displayName = "";
        if (visible) {
            opening.restart();
            // From the Apps panel: an app's details.
            if (Settings.appToShow) {
                Apps.open();
                Apps.show(Settings.appToShow);
                page = "app";
                Settings.appToShow = null;
            }
            if (section.id === "apps" && !page)
                store.focusSearch();
            else
                search.forceActiveFocus();
            zone.running = true;
            // A mouse or touchpad may have come since.
            Pointer.refresh();
            if (!timeZones.length)
                zones.running = true;
            locale.running = true;
            if (!locales.length)
                localeList.running = true;
        }
    }

    // timedatectl show prints "Timezone=Europe/Warsaw" and "NTP=yes".
    Process {
        id: zone
        command: ["timedatectl", "show", "--property=Timezone", "--property=NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = name => (text.match(new RegExp(`^${name}=(.*)$`, "m")) ?? [])[1] ?? "";
                window.timeZone = value("Timezone");
                window.automaticTime = value("NTP") === "yes";
            }
        }
    }
    Process {
        id: zones
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: window.timeZones = text.trim().split("\n")
        }
    }
    // localectl status prints "System Locale: LANG=en_GB.UTF-8".
    Process {
        id: locale
        command: ["localectl", "status"]
        stdout: StdioCollector {
            onStreamFinished: window.systemLocale = (text.match(/LANG=(\S+)/) ?? [])[1] ?? ""
        }
    }
    Process {
        id: localeList
        command: ["localectl", "list-locales"]
        stdout: StdioCollector {
            onStreamFinished: window.locales = text.trim().split("\n").filter(l => l.endsWith(".UTF-8"))
        }
    }
    Process {
        id: localeSetter
        onRunningChanged: {
            if (!running)
                locale.running = true;
        }
    }
    Process {
        id: timeSetter
        onRunningChanged: {
            if (!running)
                zone.running = true;
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: window.page ? window.page = "" : window.close()
    }

    // How far the bars on an edge of this screen reach into it.
    function reserved(edge: string): real {
        return Shell.bars.filter(b => b.modelData === window.modelData && b.edge === edge)
            .reduce((sum, b) => sum + b.depth, 0);
    }

    // The space between the bars, where windows are. Settings shows the
    // wallpaper there rather than the windows: the empty desktop, which the
    // bars stand on too.
    Item {
        id: workArea

        x: window.reserved("Left")
        y: window.reserved("Top")
        width: window.width - x - window.reserved("Right")
        height: window.height - y - window.reserved("Bottom")
        clip: true

        Backdrop {
            x: -workArea.x
            y: -workArea.y
            width: window.width
            height: window.height
        }
    }

    // Everything but Settings, the bars too, slightly dimmed.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim(0.2)
    }

    // A click beside the card closes Settings, as outside a panel.
    MouseArea {
        anchors.fill: workArea
        onClicked: window.close()
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 6
        blur: 24
        color: Theme.shadow(0.16)
    }

    // Settings itself, inset so the desktop shows around it, at least as far
    // as windows are apart and far enough not to look like one of them; in
    // the corners of the windows.
    Rectangle {
        id: card

        anchors.fill: workArea
        anchors.margins: Math.max(Theme.gap, 16)
        radius: Theme.rounded ? 9 : 0
        color: Theme.background
        border.color: Theme.line
        transformOrigin: Item.Center

        // It grows out of the desktop when it opens.
        ParallelAnimation {
            id: opening

            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.98; to: 1; duration: 150; easing.type: Easing.OutCubic }
        }

        // Clicks on the card stay on it.
        MouseArea {
            anchors.fill: parent
        }

        // The sections.
        Rectangle {
            id: sidebar

            x: 1
            y: 1
            width: 228
            height: parent.height - 2
            topLeftRadius: Math.max(card.radius - 1, 0)
            bottomLeftRadius: topLeftRadius
            color: Theme.surfaceSunken

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.line
            }

            Column {
                id: heading

                x: 10
                y: 18
                width: parent.width - 20
                spacing: 14

                Text {
                    leftPadding: 8
                    text: "Settings"
                    color: Theme.textStrong
                    font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                }

                Rectangle {
                    x: 2
                    width: parent.width - 4
                    height: 30
                    color: Theme.surface
                    border.color: Theme.lineStrong

                    Icon {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 12
                        color: Theme.textMuted
                        strokeWidth: 1.5
                        strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM10.4 10.4L14 14"
                    }
                    TextInput {
                        id: search

                        anchors { left: parent.left; right: parent.right; leftMargin: 30; rightMargin: 10 }
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textStrong
                        selectionColor: Theme.accent
                        font { family: Theme.font; pixelSize: 12 }
                        clip: true
                        onTextChanged: {
                            if (text)
                                window.page = "";
                        }

                        Text {
                            visible: !search.text
                            text: "Find a setting"
                            color: Theme.textMuted
                            font: search.font
                        }
                    }
                }

            }

            // The groups, which scroll when the screen is too short for them.
            Flickable {
                x: 10
                y: heading.y + heading.height + 14
                width: parent.width - 20
                height: parent.height - y
                contentHeight: groupList.height + 18
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: groupList

                    width: parent.width
                    spacing: 14

                    Repeater {
                        model: window.groups

                        Column {
                            id: group

                            required property var modelData
                            required property int index

                            width: parent.width
                            topPadding: index > 0 ? 14 : 0
                            spacing: 2

                            Rectangle {
                                visible: group.index > 0
                                y: 0
                                width: parent.width
                                height: 1
                                color: Theme.line
                            }

                            Repeater {
                                model: group.modelData

                                Rectangle {
                                    id: entry

                                    required property string modelData
                                    readonly property var section: window.sections.find(s => s.id === modelData)
                                    readonly property bool current: !window.query && Settings.section === modelData

                                    width: group.width
                                    height: 36
                                    color: current ? Theme.surface : entryHover.hovered ? Theme.hoverStrong : "transparent"

                                    Icon {
                                        x: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 15
                                        color: entry.current ? Theme.textStrong : Theme.textBody
                                        strokes: entry.section.icon
                                    }
                                    Text {
                                        x: 35
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: entry.section.name
                                        color: entry.current ? Theme.textStrong : Theme.textBody
                                        font { family: Theme.font; pixelSize: 13; weight: entry.current ? Font.DemiBold : Font.Normal }
                                    }

                                    TapHandler {
                                        onTapped: window.show(entry.modelData)
                                    }
                                    HoverHandler {
                                        id: entryHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // The open section, or page.
        Item {
            anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 14
                width: 30
                height: 30
                color: closeHover.hovered ? Theme.hover : "transparent"

                Icon {
                    anchors.centerIn: parent
                    height: 10
                    gridWidth: 8
                    gridHeight: 8
                    strokeWidth: 1.3
                    color: Theme.textBody
                    strokes: "M1 1l6 6M7 1l-6 6"
                }

                TapHandler {
                    onTapped: window.close()
                }
                HoverHandler {
                    id: closeHover
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Flickable {
                x: 36
                y: 62
                // The store of apps has room for more.
                width: Math.min(window.section.id === "apps" && !window.query ? 980 : 620, parent.width - 72)
                height: parent.height - y
                contentHeight: content.height + 36
                clip: true

                Column {
                    id: content

                    width: parent.width
                    spacing: 16

                    // A page: the way back, and its title.
                    Row {
                        visible: window.page !== ""
                        spacing: 10

                        Rectangle {
                            width: 26
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            color: backHover.hovered ? Theme.hover : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                height: 10
                                gridWidth: 10
                                gridHeight: 10
                                strokeWidth: 1.4
                                color: Theme.textBody
                                strokes: "M6.5 2l-3 3 3 3"
                            }
                            TapHandler {
                                onTapped: window.page = ""
                            }
                            HoverHandler {
                                id: backHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: window.pages[window.page]?.[0] ?? ""
                            color: Theme.textStrong
                            font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                        }
                    }

                    ImagePicker {
                        visible: window.page === "picture" || window.page === "wallpaper"
                        width: parent.width
                        onPicked: path => {
                            if (window.page === "picture") {
                                Account.setPicture(path);
                            } else {
                                Settings.wallpaperImage = path;
                                Settings.wallpaper = "Image";
                            }
                            window.page = "";
                        }
                    }

                    KeyboardsPage {
                        visible: window.page === "keyboards"
                        width: parent.width
                    }

                    PasswordPage {
                        visible: window.page === "password"
                        width: parent.width
                    }

                    ConnectionsPage {
                        visible: window.page === "wifi" || window.page === "bluetooth"
                        kind: window.page
                        width: parent.width
                    }

                    AppsPage {
                        id: store

                        visible: window.page === "" && !window.query && window.section.id === "apps"
                        width: parent.width
                        onOpened: app => {
                            Apps.show(app);
                            window.page = "app";
                        }
                    }

                    AppPage {
                        visible: window.page === "app"
                        width: parent.width
                    }

                    DownloadsPage {
                        visible: window.page === "" && !window.query && window.section.id === "downloads"
                        width: parent.width
                    }

                    AssistantSkillsPage {
                        visible: window.page === "assistant-skills"
                        width: parent.width
                    }

                    AssistantModelsPage {
                        visible: window.page === "assistant-models"
                        width: parent.width
                    }

                    Rectangle {
                        visible: (window.page === "" || window.pageRows[window.page] !== undefined) && window.rows.length > 0
                        width: parent.width
                        height: list.height + 2
                        color: Theme.surface
                        border.color: Theme.line

                        Column {
                            id: list

                            x: 1
                            y: 1
                            width: parent.width - 2

                            // Rows are made again only when their number changes;
                            // their values change often, such as the volume.
                            Repeater {
                                model: window.rows.length

                                Column {
                                    id: row

                                    required property int index

                                    width: list.width

                                    Rectangle {
                                        visible: row.index > 0
                                        width: parent.width
                                        height: 1
                                        color: Theme.lineSoft
                                    }
                                    SettingsRow {
                                        width: parent.width
                                        height: implicitHeight
                                        modelData: window.rows[row.index] ?? {}
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: window.page === "" && window.query !== "" && window.rows.length === 0
                        text: `No settings match “${search.text.trim()}”`
                        color: Theme.textMuted
                        font { family: Theme.font; pixelSize: 13 }
                    }
                }
            }
        }
    }
}
