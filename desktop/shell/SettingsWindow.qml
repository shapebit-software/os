// Settings, over the whole screen it was opened on, as in the demo: sections
// in groups on the left with a search across all of them, and the open
// section's settings on the right (SettingsRow.qml). Some settings lead to a
// page of their own, such as choosing a picture. Escape or the close button
// closes it; on a page, Escape goes back.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    // The output's modes, such as "2560x1600@120.00Hz", as sizes and rates.
    readonly property var modes: (monitor?.lastIpcObject.availableModes ?? []).map(m => {
        const [size, rate] = m.replace(/Hz$/, "").split("@");
        return { size, rate: Math.round(parseFloat(rate)) };
    })
    readonly property string size: monitor ? `${monitor.width}x${monitor.height}` : ""
    readonly property int rate: Math.round(monitor?.lastIpcObject.refreshRate ?? 0)
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

    // The open page, or none: "picture", "wallpaper", or "keyboards".
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
        ] },
        { id: "assistant", name: "Assistant", icon: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z", rows: [
            { label: "Coming soon", detail: "Assistant settings will be available in a future update.", kind: "info" },
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
            { label: "Layout", detail: "Drag items to reorder them or move them between zones", kind: "shell" },
            { label: "System bar", detail: "Clock and status icons", kind: "choice",
              options: Shell.edges, selected: Settings.systemBar, select: o => Shell.place("system", o) },
            { label: "Dock", detail: "Apps, workspaces and quick actions", kind: "choice",
              options: Shell.edges, selected: Settings.dock, select: o => Shell.place("dock", o) },
            { label: "Bar background", detail: "Fill behind the bars", kind: "choice",
              options: ["None", "Glass", "Solid"], selected: Settings.barBackground,
              select: o => Settings.barBackground = o },
            { label: "Quick actions", detail: "How the screenshot and record actions open", kind: "choice",
              options: ["Buttons", "Hot corner"], selected: Settings.quickActions,
              select: o => Settings.quickActions = o },
            ...(Battery.available ? [{ label: "Battery percentage", detail: "Beside the battery in the system bar", kind: "choice",
              options: ["Shown", "Hidden"], selected: Settings.batteryPercentage,
              select: o => Settings.batteryPercentage = o }] : []),
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
            { label: "Resolution", detail: monitor?.name ?? "", kind: "select",
              options: [...new Set(modes.map(m => m.size))].map(s => [s.replace("x", " × "), s]),
              selected: size,
              select: s => Settings.setMode(monitor.name, `${s}@${Math.max(...modes.filter(m => m.size === s).map(m => m.rate))}`) },
            { label: "Scale", detail: "Size of text and interface", kind: "choice",
              options: ["100%", "125%", "150%", "200%"],
              selected: `${Math.round((monitor?.scale ?? 1) * 100)}%`,
              select: o => Settings.setScale(monitor.name, parseInt(o) / 100) },
            { label: "Refresh rate", detail: monitor?.name ?? "", kind: "select",
              options: [...new Set(modes.filter(m => m.size === size).map(m => m.rate))].map(r => [`${r} Hz`, r]),
              selected: rate, select: r => Settings.setMode(monitor.name, `${size}@${r}`) },
        ] },
        { id: "network", name: "Network", icon: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z", rows: [
            ...(Connectivity.wired.length ? [{ label: "Ethernet", detail: "Wired connection",
              value: Connectivity.wiredConnected ? "Connected" : "Disconnected" }] : []),
            ...(Connectivity.wifi ? [{ label: "Wi-Fi", detail: Connectivity.wifiDetail, kind: "toggle",
              on: Networking.wifiEnabled, toggle: () => Connectivity.toggleWifi() }] : []),
            ...(Connectivity.adapter ? [{ label: "Bluetooth", detail: Connectivity.bluetoothDetail, kind: "toggle",
              on: Connectivity.adapter.enabled, toggle: () => Connectivity.toggleBluetooth() }] : []),
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
        ["desktop", "shell", "windows"],
        ["display", "network", "sound"],
    ]
    // The pages: their title, and the section they belong to.
    readonly property var pages: ({
        "picture": ["Choose a picture", "account"],
        "wallpaper": ["Choose a wallpaper", "desktop"],
        "keyboards": ["Keyboards", "language"],
        "password": ["Change password", "account"],
    })

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var section: sections.find(s => s.id === Settings.section) ?? sections[0]
    readonly property var rows: query
        ? sections.flatMap(s => s.rows).filter(r => (r.label + " " + r.detail).toLowerCase().includes(query))
        : section.rows

    function close() {
        Settings.openOn = "";
    }

    function show(id: string) {
        search.text = "";
        page = "";
        Settings.section = id;
    }

    screen: modelData
    visible: Settings.openOn === (modelData?.name ?? "")
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "settings"
    // It covers the screen, so taking the keyboard holds back nothing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#f4f5f7"

    onVisibleChanged: {
        search.text = "";
        page = "";
        if (visible) {
            search.forceActiveFocus();
            zone.running = true;
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
                const values = Object.fromEntries(text.trim().split("\n").map(line => line.split("=")));
                window.timeZone = values.Timezone ?? "";
                window.automaticTime = values.NTP === "yes";
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

    // The sections.
    Rectangle {
        id: sidebar

        width: 228
        height: parent.height
        color: "#e9ebee"

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#d8dbde"
        }

        Column {
            x: 10
            y: 18
            width: parent.width - 20
            spacing: 14

            Text {
                leftPadding: 8
                text: "Settings"
                color: "#1d2022"
                font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
            }

            Rectangle {
                x: 2
                width: parent.width - 4
                height: 30
                color: "white"
                border.color: "#d1d5d8"

                Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 12
                    color: "#5f6469"
                    strokeWidth: 1.5
                    strokes: "M2.4 7a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM10.4 10.4L14 14"
                }
                TextInput {
                    id: search

                    anchors { left: parent.left; right: parent.right; leftMargin: 30; rightMargin: 10 }
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#1d2022"
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
                        color: "#65696f"
                        font: search.font
                    }
                }
            }

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
                        color: "#d8dbde"
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
                            color: current ? "white" : entryHover.hovered ? "#e1e3e6" : "transparent"

                            Icon {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 15
                                color: entry.current ? "#181b1e" : "#3e4348"
                                strokes: entry.section.icon
                            }
                            Text {
                                x: 35
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.section.name
                                color: entry.current ? "#181b1e" : "#3e4348"
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

    // The open section, or page.
    Item {
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 14
            width: 30
            height: 30
            color: closeHover.hovered ? "#e6e8ea" : "transparent"

            Icon {
                anchors.centerIn: parent
                height: 10
                gridWidth: 8
                gridHeight: 8
                strokeWidth: 1.3
                color: "#44484d"
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
            width: Math.min(620, parent.width - 72)
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
                        color: backHover.hovered ? "#e6e8ea" : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            height: 10
                            gridWidth: 10
                            gridHeight: 10
                            strokeWidth: 1.4
                            color: "#44484d"
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
                        color: "#1d2022"
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

                Rectangle {
                    visible: window.page === "" && window.rows.length > 0
                    width: parent.width
                    height: list.height + 2
                    color: "white"
                    border.color: "#d8dbde"

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
                                    color: "#e6e8ea"
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
                    visible: window.page === "" && window.rows.length === 0
                    text: `No settings match “${search.text.trim()}”`
                    color: "#5f6469"
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }
    }
}
