// Settings, over the whole screen it was opened on: sections on the left, the
// open section's settings on the right, and a search across all of them.
// Escape or the close button closes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    // Each section: { id, name, rows }. Each row: { label, detail } and one of
    // a value { value }, a choice { options, selected, select(option) }, or a
    // switch { on, toggle() }.
    readonly property var sections: [
        { id: "account", name: "Account", rows: [
            { label: "Name", detail: "Shown on the lock screen and in the system menu", value: Account.displayName },
            { label: "Lock automatically", detail: "After the computer has been idle",
              options: Object.keys(Settings.lockTimes), selected: Settings.autolock,
              select: o => Settings.autolock = o },
        ] },
        { id: "appearance", name: "Appearance", rows: [
            { label: "Accent", detail: "Used for focus, selection and switches",
              options: Object.keys(Settings.accents), selected: Settings.accent,
              select: o => Settings.accent = o },
            { label: "Window gaps", detail: "Space between tiled windows",
              options: Object.keys(Settings.gapSizes), selected: Settings.gaps,
              select: o => Settings.gaps = o },
            { label: "Reduce transparency", detail: "Solid backgrounds for the bar and menus",
              on: Settings.reduceTransparency,
              toggle: () => Settings.reduceTransparency = !Settings.reduceTransparency },
        ] },
        { id: "display", name: "Display", rows: [
            { label: "Resolution", detail: monitor?.name ?? "",
              value: monitor ? `${monitor.width} × ${monitor.height}` : "" },
            { label: "Scale", detail: "Size of text and interface",
              options: ["100%", "125%", "150%", "200%"],
              selected: `${Math.round((monitor?.scale ?? 1) * 100)}%`,
              select: o => Settings.setScale(monitor.name, parseInt(o) / 100) },
            { label: "Refresh rate", detail: monitor?.name ?? "",
              value: `${Math.round(monitor?.lastIpcObject.refreshRate ?? 0)} Hz` },
        ] },
        { id: "network", name: "Network", rows: [
            ...(Connectivity.wired.length ? [{ label: "Ethernet", detail: "Wired connection",
              value: Connectivity.wiredConnected ? "Connected" : "Disconnected" }] : []),
            ...(Connectivity.wifi ? [{ label: "Wi-Fi", detail: Connectivity.wifiDetail,
              on: Networking.wifiEnabled, toggle: () => Connectivity.toggleWifi() }] : []),
            ...(Connectivity.adapter ? [{ label: "Bluetooth", detail: Connectivity.bluetoothDetail,
              on: Connectivity.adapter.enabled, toggle: () => Connectivity.toggleBluetooth() }] : []),
        ] },
        { id: "sound", name: "Sound", rows: [
            { label: "Output", detail: Audio.output?.description ?? "No device",
              value: `${Math.round((Audio.output?.audio?.volume ?? 0) * 100)}%` },
            { label: "Input", detail: Audio.input?.description ?? "No device",
              value: `${Math.round((Audio.input?.audio?.volume ?? 0) * 100)}%` },
        ] },
    ]

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var section: sections.find(s => s.id === Settings.section) ?? sections[0]
    readonly property string title: query ? "Results" : section.name
    readonly property var rows: query
        ? sections.flatMap(s => s.rows).filter(r => (r.label + " " + r.detail).toLowerCase().includes(query))
        : section.rows

    function close() {
        Settings.openOn = "";
    }

    screen: modelData
    visible: Settings.openOn === modelData.name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "settings"
    // It covers the screen, so taking the keyboard holds back nothing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#f4f5f7"

    onVisibleChanged: {
        search.text = "";
        if (visible)
            search.forceActiveFocus();
    }

    Shortcut {
        sequence: "Escape"
        onActivated: window.close()
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

            Row {
                leftPadding: 8
                spacing: 10

                Rectangle {
                    width: 26
                    height: 26
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: Account.displayName.charAt(0).toUpperCase()
                        color: "#f5feff"
                        font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    color: "#1d2022"
                    font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
                }
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

                    Text {
                        visible: !search.text
                        text: "Find a setting"
                        color: "#65696f"
                        font: search.font
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: window.sections

                    Rectangle {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool current: !window.query && Settings.section === modelData.id

                        width: parent.width
                        height: 36
                        color: current ? "white" : entryHover.hovered ? "#dfe1e4" : "transparent"

                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.name
                            color: entry.current ? "#181b1e" : "#3e4348"
                            font { family: Theme.font; pixelSize: 13; weight: entry.current ? Font.DemiBold : Font.Normal }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(entry.index + 1).padStart(2, "0")
                            color: "#65696f"
                            font { family: Theme.mono; pixelSize: 10 }
                        }

                        TapHandler {
                            onTapped: {
                                search.text = "";
                                Settings.section = entry.modelData.id;
                            }
                        }
                        HoverHandler {
                            id: entryHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }

        Text {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: parent.width - 40
            wrapMode: Text.Wrap
            text: [Account.system, Account.hostname].filter(s => s).join(" · ")
            color: "#5f6469"
            font { family: Theme.mono; pixelSize: 10 }
            lineHeight: 1.5
        }
    }

    // The open section.
    Item {
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        Text {
            x: 36
            y: 22
            text: `Settings / ${window.title}`.toUpperCase()
            color: "#5f6469"
            font { family: Theme.mono; pixelSize: 11; letterSpacing: 1.3 }
        }

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
                spacing: 22

                Text {
                    text: window.title
                    color: "#1d2022"
                    font { family: Theme.font; pixelSize: 26; weight: Font.DemiBold; letterSpacing: -0.5 }
                }

                Rectangle {
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

                            Item {
                                id: row

                                required property int index
                                readonly property var modelData: window.rows[index] ?? {}

                                width: list.width
                                height: Math.max(56, labels.height + 20)

                                Rectangle {
                                    visible: row.index > 0
                                    width: parent.width
                                    height: 1
                                    color: "#e6e8ea"
                                }

                                Column {
                                    id: labels

                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 32 - control.width - 16
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: row.modelData.label
                                        color: "#1d2022"
                                        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                                    }
                                    Text {
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        text: row.modelData.detail
                                        color: "#5f6469"
                                        font { family: Theme.font; pixelSize: 12 }
                                    }
                                }

                                Item {
                                    id: control

                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: childrenRect.width
                                    height: childrenRect.height

                                    // A value.
                                    Text {
                                        visible: row.modelData.value !== undefined
                                        text: row.modelData.value ?? ""
                                        color: "#44484d"
                                        font { family: Theme.font; pixelSize: 12 }
                                    }

                                    // A switch.
                                    Rectangle {
                                        visible: row.modelData.toggle !== undefined
                                        width: 30
                                        height: 17
                                        radius: 9
                                        color: row.modelData.on ? Theme.accent : "#d5d8db"

                                        Rectangle {
                                            x: row.modelData.on ? 15 : 2
                                            y: 2
                                            width: 13
                                            height: 13
                                            radius: 7
                                            color: "white"

                                            Behavior on x { NumberAnimation { duration: 120 } }
                                        }

                                        TapHandler {
                                            onTapped: row.modelData.toggle()
                                        }
                                        HoverHandler {
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }

                                    // A choice.
                                    Rectangle {
                                        visible: row.modelData.options !== undefined
                                        width: options.width + 4
                                        height: options.height + 4
                                        color: "#eceff1"

                                        Row {
                                            id: options

                                            x: 2
                                            y: 2
                                            spacing: 2

                                            Repeater {
                                                model: row.modelData.options?.length ?? 0

                                                Item {
                                                    id: option

                                                    required property int index
                                                    readonly property string modelData: row.modelData.options?.[index] ?? ""
                                                    readonly property bool selected: row.modelData.selected === modelData

                                                    width: optionText.width + 20
                                                    height: 26

                                                    RectangularShadow {
                                                        visible: option.selected
                                                        anchors.fill: parent
                                                        offset.y: 1
                                                        blur: 2
                                                        color: Qt.rgba(0, 0, 0, 0.14)
                                                    }
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: option.selected ? "white" : "transparent"
                                                    }
                                                    Text {
                                                        id: optionText
                                                        anchors.centerIn: parent
                                                        text: option.modelData
                                                        color: option.selected ? "#181b1e" : "#54595e"
                                                        font { family: Theme.font; pixelSize: 12 }
                                                    }

                                                    TapHandler {
                                                        onTapped: row.modelData.select(option.modelData)
                                                    }
                                                    HoverHandler {
                                                        cursorShape: Qt.PointingHandCursor
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: window.rows.length === 0
                    text: window.query ? `No settings match “${search.text.trim()}”` : ""
                    color: "#5f6469"
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }
    }
}
