// The panel of a sound device, the output or the input: a mute button, the
// device's name and volume, and a slider.
import QtQuick
import Quickshell.Services.Pipewire

BarPanel {
    id: panel

    property PwNode node
    // The device's icon, as for Icon, and the line drawn over it when muted.
    property string strokes
    property string fills
    property string mutedStroke
    // Whether `strokes` still show when muted; the speaker loses its waves.
    property bool wavesWhenMuted: true

    readonly property bool muted: node?.audio?.muted ?? false
    readonly property real volume: node?.audio?.volume ?? 0

    function setVolume(x: real, width: real) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, x / width));
    }

    Row {
        width: parent.width
        spacing: 12

        Rectangle {
            id: mute

            width: 36
            height: 36
            color: panel.muted ? Theme.oklch(0.52, 0.17, 25) : Theme.veil(muteHover.hovered ? 0.12 : 0.08)

            Icon {
                anchors.centerIn: parent
                color: panel.muted ? "#fbfbfd" : Theme.ink
                strokes: panel.muted && !panel.wavesWhenMuted ? "" : panel.strokes
                fills: panel.fills
            }
            Icon {
                anchors.centerIn: parent
                visible: panel.muted
                color: "#fbfbfd"
                strokeWidth: 1.6
                strokes: panel.mutedStroke
            }

            TapHandler {
                onTapped: {
                    if (panel.node?.audio)
                        panel.node.audio.muted = !panel.muted;
                }
            }
            HoverHandler {
                id: muteHover
                cursorShape: Qt.PointingHandCursor
            }
        }

        Column {
            width: parent.width - mute.width - parent.spacing - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Item {
                width: parent.width
                height: name.height

                Text {
                    id: name
                    width: parent.width - percent.width - 8
                    elide: Text.ElideRight
                    text: panel.node?.description || panel.node?.nickname || "No device"
                    color: Theme.inkSoft
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    id: percent
                    anchors.right: parent.right
                    anchors.baseline: name.baseline
                    text: Math.round(panel.volume * 100) + "%"
                    color: Theme.inkFaint
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }

            // The slider: the track, the volume in the accent, and a knob.
            Item {
                width: parent.width
                height: 4
                opacity: panel.muted ? 0.35 : 1

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Theme.veil(0.07)
                }
                Rectangle {
                    width: parent.width * Math.min(1, panel.volume)
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
                Rectangle {
                    x: parent.width * Math.min(1, panel.volume) - width / 2
                    y: -6
                    width: 16
                    height: 16
                    radius: 8
                    color: "#fbfbfd"
                    border.color: Theme.veil(0.12)
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => panel.setVolume(mouse.x, width)
                    onPositionChanged: mouse => panel.setVolume(mouse.x, width)
                }
            }
        }
    }
}
