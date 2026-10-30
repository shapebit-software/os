// The battery's panel (Battery.qml): the power profiles to choose from, the
// chosen one lit. The charge is on the bar's icon and in its tooltip.
pragma ComponentBehavior: Bound
import QtQuick

BarPanel {
    id: panel

    panelWidth: 240

    Column {
        width: parent.width
        spacing: 4

        Repeater {
            model: Battery.profiles

            Rectangle {
                id: option

                required property var modelData
                readonly property bool chosen: Battery.profile === modelData.profile

                width: parent.width
                height: 44
                color: chosen ? Theme.accentSoft : Theme.veil(optionHover.hovered ? 0.1 : 0.05)

                Column {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: option.modelData.name
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                    }
                    Text {
                        text: option.modelData.detail
                        color: Theme.inkFaint
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: option.chosen
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent
                }

                TapHandler {
                    onTapped: Battery.setProfile(option.modelData.profile)
                }
                HoverHandler {
                    id: optionHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
