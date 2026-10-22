// The capture panel beside the quick actions, as in the demo: what to capture
// (an area, a window, or the screen), then a screenshot or a recording.
pragma ComponentBehavior: Bound
import QtQuick
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

    PopoverFrame {
        padding: 8

        Column {
            width: 304
            spacing: 4

            // What to capture.
            Row {
                spacing: 4

                Repeater {
                    model: [
                        { label: "Area", strokes: "M2.75 4.75h14.5v10.5H2.75z", dashed: true },
                        { label: "Window", strokes: "M2.75 4.75h14.5v10.5H2.75zM2.75 8h14.5", dashed: false },
                        { label: "Screen", strokes: "M2.75 3.75h14.5v9.5H2.75zM7 16.25h6M10 13.25v3", dashed: false },
                    ]

                    Rectangle {
                        id: area

                        required property var modelData
                        readonly property bool selected: panel.mode === modelData.label
                        readonly property color ink: selected ? Theme.accent : Theme.oklch(0.38, 0.07, 290)

                        width: (304 - 8) / 3
                        height: 62
                        color: selected ? Theme.accentSoft : Theme.veil(areaHover.hovered ? 0.09 : 0.04)

                        Column {
                            anchors.centerIn: parent
                            spacing: 7

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 20
                                gridWidth: 20
                                gridHeight: 20
                                strokeWidth: 1.5
                                color: area.ink
                                strokes: area.modelData.strokes
                                dashed: area.modelData.dashed
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: area.modelData.label
                                color: area.ink
                                font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                            }
                        }

                        TapHandler {
                            onTapped: panel.mode = area.modelData.label
                        }
                        HoverHandler {
                            id: areaHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            // How: a screenshot on the accent, or a recording.
            Row {
                spacing: 4

                Rectangle {
                    width: 150
                    height: 36
                    color: Theme.accent

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 15
                            color: "#fbfbfd"
                            strokes: "M2 5h2.6l1.2-1.8h4.4L11.4 5H14v8H2zM5.7 8.8a2.3 2.3 0 1 0 4.6 0a2.3 2.3 0 1 0-4.6 0z"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Screenshot"
                            color: "#fbfbfd"
                            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "white"
                        opacity: shotHover.hovered ? 0.08 : 0
                    }

                    TapHandler {
                        onTapped: panel.capture(false)
                    }
                    HoverHandler {
                        id: shotHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                Rectangle {
                    width: 150
                    height: 36
                    color: Theme.veil(recordHover.hovered ? 0.11 : 0.06)

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Theme.oklch(0.58, 0.2, 25)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Record"
                            color: Theme.oklch(0.27, 0.06, 290)
                            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
                        }
                    }

                    TapHandler {
                        onTapped: panel.capture(true)
                    }
                    HoverHandler {
                        id: recordHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
