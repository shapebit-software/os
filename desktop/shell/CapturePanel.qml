// The capture panel beside the quick actions: what to capture (an area, a
// window, or the screen), then a screenshot or a recording.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Wayland

Popout {
    id: panel

    property string mode: "Area"

    // Closes the panel, then captures once it is gone from the screen.
    function capture(record: bool) {
        dismissed();
        pendingRecord = record;
        afterClose.restart();
    }
    property bool pendingRecord

    name: "capture"
    // The compositor leaves this namespace out of captures' way
    // (compositor/hyprland.lua).
    WlrLayershell.namespace: "capture"

    Timer {
        id: afterClose
        interval: 250
        onTriggered: Capture.start(panel.mode, panel.pendingRecord, panel.screen)
    }

    RectangularShadow {
        anchors.fill: frame
        offset.y: 8
        blur: 24
        radius: frame.radius
        color: Qt.rgba(0.01, 0.01, 0.04, 0.28)
    }

    Rectangle {
        id: frame

        width: 320
        height: column.height + 20
        radius: 14
        color: Qt.rgba(0.12, 0.12, 0.15, 0.82)
        border.color: Qt.rgba(1, 1, 1, 0.1)

        Column {
            id: column

            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8

            // What to capture.
            Rectangle {
                width: parent.width
                height: 36
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    x: 3
                    y: 3
                    spacing: 2

                    Repeater {
                        model: ["Area", "Window", "Screen"]

                        Rectangle {
                            id: choice

                            required property string modelData
                            readonly property bool selected: panel.mode === modelData

                            width: (column.width - 6 - 4) / 3
                            height: 30
                            radius: height / 2
                            color: selected ? Qt.rgba(1, 1, 1, 0.16) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: choice.modelData
                                color: choice.selected ? "#f3f5f8" : "#acb2b7"
                                font { family: Theme.font; pixelSize: 12 }
                            }

                            TapHandler {
                                onTapped: panel.mode = choice.modelData
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            // How.
            Row {
                spacing: 8

                Repeater {
                    model: [
                        { label: "Screenshot", record: false,
                          strokes: "M2.5 5.5v-3h3M10.5 2.5h3v3M13.5 10.5v3h-3M5.5 13.5h-3v-3M5.8 8a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0-4.4 0z",
                          fills: "" },
                        { label: "Record", record: true,
                          strokes: "M2.8 3.5h10.4a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H2.8a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1z",
                          fills: "M6 8a2 2 0 1 0 4 0a2 2 0 1 0-4 0z" },
                    ]

                    Rectangle {
                        id: action

                        required property var modelData

                        width: (column.width - 8) / 2
                        height: 40
                        radius: 10
                        color: Qt.rgba(1, 1, 1, actionHover.hovered ? 0.14 : 0.07)

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                color: "#e7ecf0"
                                strokes: action.modelData.strokes
                                fills: action.modelData.fills
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: action.modelData.label
                                color: "#f0f2f4"
                                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                            }
                        }

                        TapHandler {
                            onTapped: panel.capture(action.modelData.record)
                        }
                        HoverHandler {
                            id: actionHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
