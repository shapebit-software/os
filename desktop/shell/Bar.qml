// The system bar of one screen: the date and time on the left, the status
// buttons on the right. The buttons do not open their panels yet.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property ShellScreen modelData

    screen: modelData
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
            // Microphone
            Icon {
                strokes: "M5.6 4.2a2.4 2.4 0 0 1 4.8 0v3.2a2.4 2.4 0 0 1-4.8 0z"
                    + "M3.4 7.6a4.6 4.6 0 0 0 9.2 0M8 12.2v2"
            }
        }
        BarButton {
            // Sound
            Icon {
                strokes: "M10.8 5.9a3 3 0 0 1 0 4.2M12.7 4.2a5.6 5.6 0 0 1 0 7.6"
                fills: "M3 6.2h2.2L8.6 3.4v9.2L5.2 9.8H3z"
            }
        }
        BarButton {
            // Network
            Icon {
                strokes: "M2.4 6.2a8 8 0 0 1 11.2 0M4.7 8.7a4.9 4.9 0 0 1 6.6 0"
                fills: "M7.1 11.6a0.9 0.9 0 1 0 1.8 0a0.9 0.9 0 1 0-1.8 0z"
                capStyle: ShapePath.SquareCap
            }
        }
        BarButton {
            // Input language: a speech bubble with the language code. Until
            // the compositor reports the keyboard layout, the code comes from
            // the locale.
            Icon {
                gridWidth: 20
                strokes: "M3 1.8h14a1.4 1.4 0 0 1 1.4 1.4v7.2a1.4 1.4 0 0 1-1.4 1.4H8.2"
                    + "l-3.6 2.8v-2.8H3a1.4 1.4 0 0 1-1.4-1.4V3.2A1.4 1.4 0 0 1 3 1.8z"

                Text {
                    x: 0
                    y: 2
                    width: parent.width
                    height: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().name.slice(0, 2).toUpperCase()
                    color: "#f6f9fb"
                    font { family: Theme.font; pixelSize: 8; weight: Font.ExtraBold }
                }
            }
        }
        BarButton {
            // Account and system
            Icon {
                strokes: "M1.7 8a6.3 6.3 0 1 0 12.6 0a6.3 6.3 0 1 0-12.6 0z"
                    + "M5.9 6.6a2.1 2.1 0 1 0 4.2 0a2.1 2.1 0 1 0-4.2 0z"
                    + "M4.1 12.8c.8-1.6 2.2-2.4 3.9-2.4s3.1.8 3.9 2.4"
            }
        }
    }
}
