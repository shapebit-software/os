// One item of a bar (ShellBar.qml), by its id in Settings.zones: the clock,
// a status button that opens its panel (the microphone, the sound, the
// network, the input language, the system menu), Apps, the workspaces, or
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

    // The quick actions open from the hot corner instead, if set so.
    active: !(modelData === "quick" && Settings.quickActions === "Hot corner")
    visible: active
    sourceComponent: ({
        clock: clock,
        microphone: microphoneButton,
        sound: soundButton,
        network: networkButton,
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
            Text {
                id: text

                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.StyledText
                // Across a bar, the date and the time; along a side, the time
                // in two lines.
                text: item.bar.vertical
                    ? Qt.formatTime(time.date, Settings.timePattern).replace(/:/, "<br>").replace(" ", "<br>")
                    : `<span style="color: ${Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.72)}; font-weight: 500">`
                        + `${Qt.formatDate(time.date, Settings.datePattern)}</span>&nbsp;&nbsp;`
                        + Qt.formatTime(time.date, Settings.timePattern)
                color: Theme.text
                lineHeight: 0.95
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
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
