// The account's picture (Account.picture), or the first letter of its name on
// the accent; square, or round.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Rectangle {
    id: avatar

    property bool round

    color: Theme.accent
    radius: round ? width / 2 : 0
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
        // Round, the picture is cut to the circle.
        layer.enabled: avatar.round
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }
}
