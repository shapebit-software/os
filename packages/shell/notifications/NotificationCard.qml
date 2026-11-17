// One notification, in a banner or in the panel: the application's icon and,
// in a banner, its name, which the panel has over each group, the summary,
// the body, and up to three of its actions as buttons. A
// click opens what it is about; the cross dismisses it. In the panel, where
// the keyboard is, one that takes a reply has a field for it: Enter sends.
pragma ComponentBehavior: Bound
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
    // The buttons: the actions but the default one, which the click is.
    // Quickshell does not declare the actions' type to tooling.
    readonly property var buttons: (notification?.actions ?? []) // qmllint disable unresolved-type
        .filter(a => a.identifier !== "default" && a.text).slice(0, 3)
    readonly property bool replies: !banner && (notification?.hasInlineReply ?? false)

    implicitHeight: Math.max(icon.visible ? icon.height : 0, text.height) + 24
    color: banner ? Theme.popoverTop : Theme.veil(hover.hovered ? 0.1 : 0.05)
    border.color: banner ? (critical ? Theme.danger : Theme.popoverRing) : "transparent"

    TapHandler {
        onTapped: Notifications.open(card.notification)
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

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
            visible: card.banner
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

        // The reply: Enter sends it, which closes the notification.
        Rectangle {
            visible: card.replies
            width: parent.width
            height: 28
            color: Theme.veil(0.06)

            TextInput {
                id: reply

                anchors { left: parent.left; right: parent.right; leftMargin: 9; rightMargin: 9 }
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 12 }
                clip: true
                onAccepted: {
                    if (reply.text.trim())
                        card.notification.sendInlineReply(reply.text);
                }

                Text {
                    visible: !reply.text
                    text: card.notification?.inlineReplyPlaceholder || "Reply"
                    color: Theme.inkFaint
                    font: reply.font
                }
            }
            // The click is the field's, not the card's.
            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                onTapped: reply.forceActiveFocus()
            }
            HoverHandler {
                cursorShape: Qt.IBeamCursor
            }
        }

        Flow {
            visible: card.buttons.length > 0
            width: parent.width
            topPadding: 4
            spacing: 6

            Repeater {
                model: card.buttons

                Rectangle {
                    id: button

                    required property var modelData

                    width: Math.min(label.implicitWidth + 20, text.width)
                    height: 24
                    color: Theme.veil(buttonHover.hovered ? 0.16 : 0.08)

                    Text {
                        id: label
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 20)
                        elide: Text.ElideRight
                        text: button.modelData.text
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 11; weight: Font.Medium }
                    }
                    // The click is the button's, not the card's.
                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: button.modelData.invoke()
                    }
                    HoverHandler {
                        id: buttonHover
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
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
        // The click is the cross's, not the card's.
        TapHandler {
            gesturePolicy: TapHandler.WithinBounds
            onTapped: card.notification?.dismiss()
        }
        HoverHandler {
            id: closeHover
            cursorShape: Qt.PointingHandCursor
        }
    }
}
