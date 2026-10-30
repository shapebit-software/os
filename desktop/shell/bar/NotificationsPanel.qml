// The notifications' panel: Do Not Disturb, the notifications kept, newest
// first (Notifications.qml), and a way to clear them all.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications
import qs.controls
import qs.notifications
import qs.services

BarPanel {
    id: panel

    panelWidth: 340

    onVisibleChanged: {
        if (visible)
            Notifications.unseen = false;
    }

    Item {
        width: parent.width
        height: 28

        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.ink
            font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Do Not Disturb"
                color: Theme.inkSoft
                font { family: Theme.font; pixelSize: 12 }
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                on: Settings.doNotDisturb
                onToggled: Settings.doNotDisturb = !Settings.doNotDisturb
            }
        }
    }

    Text {
        x: 6
        visible: Notifications.all.length === 0
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
            spacing: 4

            Repeater {
                model: Notifications.all

                NotificationCard {
                    required property Notification modelData
                    width: list.width
                    notification: modelData
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
