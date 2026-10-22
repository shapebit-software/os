// The network panel: wired, Wi-Fi, and Bluetooth, each when the computer has
// it. The connection in use is lit; Wi-Fi and Bluetooth have switches.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking

BarPanel {
    id: panel

    spacing: 2

    component Entry: Rectangle {
        id: entry

        property string title
        property string detail
        property bool lit
        property bool switchable
        property bool on
        default property alias icon: iconHolder.data
        signal toggled

        width: panel.panelWidth - 20
        height: 46
        color: lit ? Theme.accentSoft : entryHover.hovered ? Theme.veil(0.07) : "transparent"

        Item {
            id: iconHolder
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 13
            height: 11
        }
        Column {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (entry.switchable ? 50 : 10)

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: entry.title
                color: Theme.ink
                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: entry.detail
                color: Theme.inkFaint
                font { family: Theme.font; pixelSize: 10 }
            }
        }
        // The switch, as on Settings: the accent with the knob right when on.
        Rectangle {
            visible: entry.switchable
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 17
            radius: 9
            color: entry.on ? Theme.accent : Theme.veil(0.12)

            Rectangle {
                x: entry.on ? 15 : 2
                y: 2
                width: 13
                height: 13
                radius: 7
                color: "#fbfbfd"

                Behavior on x { NumberAnimation { duration: 120 } }
            }
            TapHandler {
                onTapped: entry.toggled()
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
        HoverHandler {
            id: entryHover
        }
    }

    Entry {
        visible: Connectivity.wired.length > 0
        title: "Ethernet"
        detail: Connectivity.wiredConnected ? "Connected" : "Disconnected"
        lit: Connectivity.wiredConnected

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1.5
            border.color: Connectivity.wiredConnected ? Theme.accent : Theme.inkFaint
        }
    }

    Entry {
        visible: Connectivity.wifi !== null
        title: "Wi-Fi"
        detail: Connectivity.wifiDetail
        lit: Connectivity.wifiNetwork !== null
        switchable: true
        on: Networking.wifiEnabled
        onToggled: Connectivity.toggleWifi()

        Row {
            anchors.bottom: parent.bottom
            spacing: 1.5

            Repeater {
                model: [4, 7, 11]

                Rectangle {
                    required property int modelData
                    anchors.bottom: parent.bottom
                    width: 2
                    height: modelData
                    color: Theme.inkFaint
                }
            }
        }
    }

    Entry {
        visible: Connectivity.adapter !== null
        title: "Bluetooth"
        detail: Connectivity.bluetoothDetail
        lit: Connectivity.bluetoothDevice !== null
        switchable: true
        on: Connectivity.adapter?.enabled ?? false
        onToggled: Connectivity.toggleBluetooth()

        Rectangle {
            anchors.centerIn: parent
            width: 9
            height: 9
            radius: 4.5
            color: "transparent"
            border.width: 1.5
            border.color: Theme.inkFaint
        }
    }

    Text {
        visible: Connectivity.wired.length === 0 && Connectivity.wifi === null && Connectivity.adapter === null
        width: panel.panelWidth - 20
        padding: 10
        text: "No network devices"
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 12 }
    }
}
