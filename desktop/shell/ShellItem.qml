// One item of a bar (ShellBar.qml), by its id in Settings.zones: the clock,
// a status button that opens its panel (the notifications, the microphone,
// the sound, the
// brightness, the network, the battery, the input language, the system menu), Apps, the workspaces, or
// the quick actions. On the dock, buttons are glass tiles; on the system bar,
// they are plain. A right click on the microphone or the sound mutes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell

Loader {
    id: item

    required property string modelData
    // The ShellBar; qmllint does not take a ShellBar for itself inside
    // ShellBar.qml, where items are made.
    required property var bar

    readonly property bool tile: bar.dock
    readonly property int size: bar.size

    // The icons of the sound devices, and the lines drawn over them when muted.
    readonly property string microphone: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0z"
        + "M3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2"
    readonly property string microphoneMuted: "M2.5 2.5l11 11"
    readonly property string speaker: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6"
    readonly property string speakerBody: "M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z"
    readonly property string speakerMuted: "M10.6 6l4 4M14.6 6l-4 4"

    function isOpen(panel: string): bool {
        return Shell.isOpen(panel, bar.modelData?.name ?? "");
    }

    function toggleMute(node: var) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    // The quick actions open from the hot corner instead, if set so; the
    // brightness shows only with a backlight, and the battery with one.
    active: !(modelData === "quick" && Settings.quickActions === "Hot corner")
        && !(modelData === "brightness" && !Brightness.available)
        && !(modelData === "battery" && !Battery.available)
    visible: active

    // A keyboard shortcut opens the item's panel (Shell.request); the
    // button's panel has the item's name.
    Connections {
        target: Shell

        function onRequested(name: string, screen: string) {
            if (name === item.modelData && screen === (item.bar.modelData?.name ?? "") && item.item)
                item.bar.open(name, item.item);
        }
    }

    sourceComponent: ({
        clock: clock,
        notifications: notificationsButton,
        microphone: microphoneButton,
        sound: soundButton,
        brightness: brightnessButton,
        network: networkButton,
        battery: batteryButton,
        language: languageButton,
        account: accountButton,
        apps: apps,
        workspaces: workspaces,
        quick: quick,
    })[modelData] ?? null

    Component {
        id: clock

        Item {
            implicitWidth: item.bar.vertical ? item.size : text.width + (item.tile ? 24 : 6)
            implicitHeight: item.bar.vertical ? text.height + 12 : item.size

            SystemClock {
                id: time
                precision: SystemClock.Minutes
            }
            Glass {
                anchors.fill: parent
                visible: item.tile
            }
            // Across a bar, the day lighter, then the time; along a side,
            // the time in two lines.
            Row {
                id: text

                anchors.centerIn: parent
                spacing: 8

                Text {
                    id: day
                    visible: !item.bar.vertical
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(time.date, Settings.datePattern)
                    color: Theme.text
                    opacity: 0.72
                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                }
                // On the day's baseline, so both sit on one line.
                Text {
                    y: day.visible ? day.y + day.baselineOffset - baselineOffset : (parent.height - height) / 2
                    horizontalAlignment: Text.AlignHCenter
                    text: item.bar.vertical
                        ? Qt.formatTime(time.date, Settings.timePattern).replace(/[: ]/, "\n")
                        : Qt.formatTime(time.date, Settings.timePattern)
                    color: Theme.text
                    lineHeight: 0.95
                    font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
    }

    Component {
        id: notificationsButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("notifications")
            onClicked: item.bar.open("notifications", button)

            // A bell; struck through with Do Not Disturb, with a dot while
            // there are new ones.
            Icon {
                strokes: "M4 11.2V7.4a4 4 0 0 1 8 0v3.8l1.2 1.4H2.8zM6.6 13.6a1.5 1.5 0 0 0 2.8 0"

                Icon {
                    anchors.fill: parent
                    visible: Settings.doNotDisturb
                    strokeWidth: 1.6
                    strokes: "M2.5 2.5l11 11"
                }
                Rectangle {
                    x: parent.width - 6
                    y: 1
                    visible: Notifications.unseen && !Settings.doNotDisturb
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                }
            }
        }
    }

    Component {
        id: microphoneButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("microphone")
            onClicked: item.bar.open("microphone", button)
            onRightClicked: item.toggleMute(Audio.input)

            Icon { strokes: item.microphone }
            Icon {
                visible: Audio.input?.audio?.muted ?? false
                color: Theme.danger
                strokeWidth: 1.6
                strokes: item.microphoneMuted
            }
        }
    }

    Component {
        id: soundButton

        BarButton {
            id: button

            readonly property bool muted: Audio.output?.audio?.muted ?? false

            tile: item.tile
            size: item.size
            open: item.isOpen("sound")
            onClicked: item.bar.open("sound", button)
            onRightClicked: item.toggleMute(Audio.output)

            Icon {
                strokes: button.muted ? "" : item.speaker
                fills: item.speakerBody
            }
            Icon {
                visible: button.muted
                color: Theme.danger
                strokeWidth: 1.6
                strokes: item.speakerMuted
            }
        }
    }

    Component {
        id: brightnessButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("brightness")
            onClicked: item.bar.open("brightness", button)

            Icon { strokes: Brightness.icon }
        }
    }

    Component {
        id: networkButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("network")
            onClicked: item.bar.open("network", button)

            Icon {
                strokes: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0"
                fills: "M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z"
                capStyle: ShapePath.SquareCap
            }
        }
    }

    Component {
        id: batteryButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("battery")
            onClicked: item.bar.open("battery", button)

            // The outline and its tip, the charge as a bar inside, and over
            // it the percentage, after a bolt while charging; red when low.
            Item {
                id: icon

                readonly property color color: Battery.low ? Theme.danger : Theme.text
                readonly property bool percentage: Settings.batteryPercentage === "Shown"

                width: 28
                height: 13

                Rectangle {
                    id: body

                    width: 25
                    height: parent.height
                    radius: 3.5
                    color: "transparent"
                    border.width: 1.2
                    border.color: icon.color

                    Rectangle {
                        x: 2
                        y: 2
                        width: (parent.width - 4) * Math.max(0.08, Battery.percent / 100)
                        height: parent.height - 4
                        radius: 1.5
                        color: icon.color
                        opacity: icon.percentage ? 0.3 : 1
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 1

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Battery.charging
                            height: 8
                            gridWidth: 6
                            gridHeight: 10
                            color: icon.color
                            fills: Battery.bolt
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: icon.percentage
                            text: Battery.percent
                            color: icon.color
                            font { family: Theme.font; pixelSize: 9; weight: Font.Bold }
                        }
                    }
                }
                Rectangle {
                    x: body.width + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 5
                    radius: 1
                    color: icon.color
                }
            }

            Tooltip {
                target: button
                edge: item.bar.edge
                hovered: button.hovered && !button.open
                text: [Battery.percent + "%", Battery.timeText].filter(t => t).join(" · ")
            }
        }
    }

    Component {
        id: languageButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("language")
            onClicked: item.bar.open("language", button)

            // A speech bubble with the active keyboard layout's language.
            Icon {
                gridWidth: 20
                strokes: "M3 1.8h14a1.4 1.4 0 0 1 1.4 1.4v7.2a1.4 1.4 0 0 1-1.4 1.4H8.2"
                    + "l-3.6 2.8v-2.8H3a1.4 1.4 0 0 1-1.4-1.4V3.2A1.4 1.4 0 0 1 3 1.8z"

                Text {
                    y: 2
                    width: parent.width
                    height: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Keyboard.code
                    color: "#f6f9fb"
                    font { family: Theme.font; pixelSize: 8; weight: Font.ExtraBold }
                }
            }
        }
    }

    Component {
        id: accountButton

        BarButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("account")
            onClicked: item.bar.open("account", button)

            Icon {
                strokes: "M1.7 8a6.3 6.3 0 1 0 12.6 0a6.3 6.3 0 1 0-12.6 0z"
                    + "M5.9 6.6a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0z"
                    + "M4.1 12.8c.8-1.6 2.2-2.4 3.9-2.4s3.1.8 3.9 2.4"
            }
        }
    }

    Component {
        id: apps

        AppsButton {
            id: button
            tile: item.tile
            size: item.size
            open: item.isOpen("apps")
            onClicked: item.bar.open("apps", button)
        }
    }

    Component {
        id: workspaces

        Workspaces {
            bar: item.bar
        }
    }

    Component {
        id: quick

        QuickActions {
            bar: item.bar
        }
    }
}
