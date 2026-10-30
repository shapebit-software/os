// One notification, in a banner or in the panel: the application's icon and
// name, the summary, and the body. A click opens what it is about; the cross
// dismisses it.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.controls
import qs.services

Rectangle {
    id: card

    required property Notification notification
    // A banner is the panels' light glass with a ring; in the panel, a tile.
    property bool banner
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical

    // The notification's image, or the application's icon if the theme has it.
    readonly property string iconSource: notification?.image
        || Quickshell.iconPath(notification?.appIcon || notification?.desktopEntry || "", true)

    implicitHeight: Math.max(icon.visible ? icon.height : 0, text.height) + 24
    color: banner ? Theme.popoverTop : Theme.veil(hover.hovered ? 0.1 : 0.05)
    border.color: banner ? (critical ? Theme.danger : Theme.popoverRing) : "transparent"

    IconImage {
        id: icon
        x: 12
        y: 12
        implicitSize: 28
        visible: card.iconSource !== ""
        source: card.iconSource
    }

    Column {
        id: text

        x: icon.visible ? icon.x + icon.width + 10 : 14
        y: 10
        width: card.width - x - 34
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.notification?.appName ?? ""
            color: Theme.inkFaint
            font { family: Theme.font; pixelSize: 11 }
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: card.notification?.summary ?? ""
            color: Theme.ink
            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
        }
        Text {
            width: parent.width
            visible: text !== ""
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: card.notification?.body ?? ""
            color: Theme.inkSoft
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    TapHandler {
        onTapped: Notifications.open(card.notification)
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    // The cross.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 22
        height: 22
        color: closeHover.hovered ? Theme.veil(0.1) : "transparent"
        visible: hover.hovered || closeHover.hovered || !card.banner

        Icon {
            anchors.centerIn: parent
            height: 12
            color: Theme.inkSoft
            strokes: "M4 4l8 8M12 4l-8 8"
        }
        TapHandler {
            onTapped: card.notification?.dismiss()
        }
        HoverHandler {
            id: closeHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
