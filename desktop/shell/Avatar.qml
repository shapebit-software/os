// The account's picture (Account.picture), or the first letter of its name on
// the accent.
import QtQuick

Rectangle {
    id: avatar

    color: Theme.accent
    clip: true

    Text {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: Account.displayName.charAt(0).toUpperCase()
        color: "#f5feff"
        font { family: Theme.font; pixelSize: Math.round(avatar.height * 0.45); weight: Font.DemiBold }
    }
    Image {
        id: picture
        anchors.fill: parent
        source: Account.picture
        sourceSize.width: avatar.width * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
}
