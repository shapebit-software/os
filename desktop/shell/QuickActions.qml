// The quick actions in the strip's corner: a glass button that shows the
// actions beside it under the pointer. While recording, it is red with the
// time, and a click stops the recording. A click otherwise keeps the actions
// shown; it opens the assistant once there is one.
import QtQuick
import QtQuick.Effects

Row {
    id: actions

    property bool pinned
    readonly property bool expanded: (hover.hovered || pinned) && !Capture.recording
    signal captureClicked

    layoutDirection: Qt.RightToLeft
    spacing: 4

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!hovered)
                actions.pinned = false;
        }
    }

    // The button.
    Item {
        width: Theme.stripHeight
        height: Theme.stripHeight

        layer.enabled: buttonHover.hovered
        layer.effect: MultiEffect { brightness: 0.2 }

        RectangularShadow {
            anchors.fill: parent
            offset.y: 6
            blur: 16
            color: Qt.rgba(0.01, 0.01, 0.04, 0.3)
        }
        Rectangle {
            anchors.fill: parent
            color: Capture.recording ? "#d23a3a" : Qt.rgba(1, 1, 1, actions.expanded ? 0.26 : 0.14)
        }

        Icon {
            anchors.centerIn: parent
            visible: !Capture.recording
            height: 20
            color: "#fbfcfd"
            strokes: "M8 1.8 9.5 6.5 14.2 8 9.5 9.5 8 14.2 6.5 9.5 1.8 8 6.5 6.5z"
        }
        Column {
            anchors.centerIn: parent
            visible: Capture.recording
            spacing: 6

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 9
                height: 9
                radius: 2
                color: "#fbfcfd"

                SequentialAnimation on opacity {
                    running: Capture.recording
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 700 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 700 }
                }
            }
            Text {
                text: Capture.elapsed
                color: "#fbfcfd"
                font { family: Theme.mono; pixelSize: 11; weight: Font.DemiBold }
            }
        }

        TapHandler {
            onTapped: {
                if (Capture.recording)
                    Capture.stop();
                else
                    actions.pinned = !actions.pinned;
            }
        }
        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // The actions.
    Item {
        visible: actions.expanded
        width: row.width + 16
        height: Theme.stripHeight

        RectangularShadow {
            anchors.fill: parent
            offset.y: 6
            blur: 16
            color: Qt.rgba(0.01, 0.01, 0.04, 0.3)
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        Row {
            id: row
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Rectangle {
                width: 44
                height: 44
                color: captureHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"

                Icon {
                    anchors.centerIn: parent
                    color: "#f0f2f4"
                    strokes: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3"
                        + "M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z"
                }

                TapHandler {
                    onTapped: {
                        actions.pinned = false;
                        actions.captureClicked();
                    }
                }
                HoverHandler {
                    id: captureHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
