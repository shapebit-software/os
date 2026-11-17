// The notifications' panel, the notification center: what is downloading and
// installing (Downloads.qml), which a click opens in Settings > Downloads;
// then the notifications kept, grouped
// by application, the group with the newest first (Notifications.qml). A group
// shows its newest, and unfolds the rest; each can be cleared, and all at once.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications
import qs.controls
import qs.notifications
import qs.services

BarPanel {
    id: panel

    // The groups unfolded, by application.
    property list<string> unfolded

    panelWidth: 340

    onVisibleChanged: {
        if (visible)
            Notifications.seen();
        else
            unfolded = [];
    }

    // What is downloading and installing.
    Column {
        visible: Downloads.active.length > 0
        width: parent.width
        spacing: 4

        Text {
            x: 6
            text: "Downloads"
            color: Theme.inkFaint
            font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
        }
        Repeater {
            model: Downloads.active

            Rectangle {
                id: job

                required property var modelData

                width: parent.width
                height: 50
                color: Theme.veil(jobHover.hovered ? 0.1 : 0.05)

                Column {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    spacing: 3

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: job.modelData.name
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Downloads.describe(job.modelData)
                        color: Theme.inkSoft
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    Rectangle {
                        visible: job.modelData.state === "running"
                        width: parent.width
                        height: 3
                        color: Theme.veil(0.12)

                        Rectangle {
                            width: parent.width * (job.modelData.percent ?? 0) / 100
                            height: parent.height
                            color: Theme.accent
                        }
                    }
                }
                TapHandler {
                    onTapped: {
                        Settings.open(panel.screenName, "downloads");
                        Shell.close();
                    }
                }
                HoverHandler {
                    id: jobHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Text {
        x: 6
        visible: Notifications.all.length === 0 && Downloads.active.length === 0
        text: "No notifications"
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 12 }
    }

    Flickable {
        visible: Notifications.all.length > 0
        width: parent.width
        height: Math.min(contentHeight, 440)
        contentHeight: list.height
        clip: true

        Column {
            id: list
            width: parent.width
            spacing: 10

            Repeater {
                model: Notifications.groups

                Column {
                    id: group

                    required property var modelData
                    readonly property bool open: panel.unfolded.includes(modelData.key)
                    readonly property int more: modelData.items.length - 1

                    width: list.width
                    spacing: 4

                    // The application, and the cross that clears its notifications.
                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            elide: Text.ElideRight
                            text: group.modelData.name
                            color: Theme.inkFaint
                            font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
                        }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            width: 20
                            height: 20
                            color: groupClear.hovered ? Theme.veil(0.1) : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                height: 11
                                color: Theme.inkSoft
                                strokes: "M4 4l8 8M12 4l-8 8"
                            }
                            TapHandler {
                                onTapped: Notifications.clearGroup(group.modelData.key)
                            }
                            HoverHandler {
                                id: groupClear
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Repeater {
                        model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)

                        NotificationCard {
                            required property Notification modelData
                            width: group.width
                            notification: modelData
                        }
                    }

                    Text {
                        x: 6
                        visible: group.more > 0
                        text: group.open ? "Show less" : `${group.more} more`
                        color: moreHover.hovered ? Theme.ink : Theme.inkSoft
                        font { family: Theme.font; pixelSize: 11; weight: Font.Medium }

                        TapHandler {
                            onTapped: panel.unfolded = group.open
                                ? panel.unfolded.filter(k => k !== group.modelData.key)
                                : [...panel.unfolded, group.modelData.key]
                        }
                        HoverHandler {
                            id: moreHover
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 6
        visible: Notifications.all.length > 0
        text: "Clear all"
        color: clearHover.hovered ? Theme.ink : Theme.inkSoft
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

        TapHandler {
            onTapped: Notifications.clear()
        }
        HoverHandler {
            id: clearHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
