// The system bar of one screen: the date and time on the left, the status
// buttons on the right. Each button opens its panel; a right click on the
// microphone or the sound mutes it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Scope {
    id: scope

    required property ShellScreen modelData

    // The open panel: "microphone", "sound", "network", "language",
    // "account", or none.
    property string panel

    function toggle(name: string) {
        panel = panel === name ? "" : name;
    }

    function toggleMute(node: var) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    // The icons of the sound devices, and the lines drawn over them when muted.
    readonly property string microphone: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0z"
        + "M3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2"
    readonly property string microphoneMuted: "M2.5 2.5l11 11"
    readonly property string speaker: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6"
    readonly property string speakerBody: "M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z"
    readonly property string speakerMuted: "M10.6 6l4 4M14.6 6l-4 4"

    PanelWindow {
        id: bar

        screen: scope.modelData
        WlrLayershell.layer: WlrLayer.Top
        // The compositor blurs behind this namespace (compositor/hyprland.lua).
        WlrLayershell.namespace: "bar"
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barHeight
        color: "transparent"

        // Glass: the backdrop shows through, blurred.
        Rectangle {
            anchors.fill: parent
            color: Theme.barGlass
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: Qt.formatDate(clock.date, "ddd d MMM")
                color: Theme.text
                opacity: 0.72
                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
            }
            Text {
                text: Qt.formatTime(clock.date, "hh:mm")
                color: Theme.text
                font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            BarButton {
                open: scope.panel === "microphone"
                onClicked: scope.toggle("microphone")
                onRightClicked: scope.toggleMute(Audio.input)

                Icon { strokes: scope.microphone }
                Icon {
                    visible: Audio.input?.audio?.muted ?? false
                    color: Theme.danger
                    strokeWidth: 1.6
                    strokes: scope.microphoneMuted
                }
            }
            BarButton {
                id: soundButton

                readonly property bool muted: Audio.output?.audio?.muted ?? false

                open: scope.panel === "sound"
                onClicked: scope.toggle("sound")
                onRightClicked: scope.toggleMute(Audio.output)

                Icon {
                    strokes: soundButton.muted ? "" : scope.speaker
                    fills: scope.speakerBody
                }
                Icon {
                    visible: soundButton.muted
                    color: Theme.danger
                    strokeWidth: 1.6
                    strokes: scope.speakerMuted
                }
            }
            BarButton {
                open: scope.panel === "network"
                onClicked: scope.toggle("network")

                Icon {
                    strokes: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0"
                    fills: "M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z"
                    capStyle: ShapePath.SquareCap
                }
            }
            BarButton {
                id: languageButton

                open: scope.panel === "language"
                onClicked: {
                    languagePanel.rightInset = bar.width - languageButton.mapToItem(null, languageButton.width, 0).x;
                    scope.toggle("language");
                }

                // A speech bubble with the active keyboard layout.
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
            BarButton {
                open: scope.panel === "account"
                onClicked: scope.toggle("account")

                Icon {
                    strokes: "M1.7 8a6.3 6.3 0 1 0 12.6 0a6.3 6.3 0 1 0-12.6 0z"
                        + "M5.9 6.6a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0z"
                        + "M4.1 12.8c.8-1.6 2.2-2.4 3.9-2.4s3.1.8 3.9 2.4"
                }
            }
        }
    }

    VolumePanel {
        screen: scope.modelData
        visible: scope.panel === "microphone"
        grabWindows: [bar]
        onDismissed: scope.panel = ""
        node: Audio.input
        strokes: scope.microphone
        mutedStroke: scope.microphoneMuted
    }
    VolumePanel {
        screen: scope.modelData
        visible: scope.panel === "sound"
        grabWindows: [bar]
        onDismissed: scope.panel = ""
        node: Audio.output
        strokes: scope.speaker
        fills: scope.speakerBody
        mutedStroke: scope.speakerMuted
        wavesWhenMuted: false
    }
    NetworkPanel {
        screen: scope.modelData
        visible: scope.panel === "network"
        grabWindows: [bar]
        onDismissed: scope.panel = ""
    }
    LanguagePanel {
        id: languagePanel
        screen: scope.modelData
        visible: scope.panel === "language"
        grabWindows: [bar]
        onDismissed: scope.panel = ""
    }
    AccountPanel {
        screen: scope.modelData
        visible: scope.panel === "account"
        grabWindows: [bar]
        onDismissed: scope.panel = ""
    }
}
