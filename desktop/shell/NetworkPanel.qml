// The network panel: wired, Wi-Fi, and Bluetooth, each when the computer has
// it. The connection in use is lit; Wi-Fi and Bluetooth have switches.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking

BarPanel {
    id: panel

    // Wired devices by their kernel names; the others without Wi-Fi are
    // virtual, such as bridges and loopback.
    readonly property var wired: Networking.devices.values
        .filter(d => d.type !== DeviceType.Wifi && /^(en|eth)/.test(d.name))
    readonly property bool wiredConnected: wired.some(d => d.connected)
    readonly property WifiDevice wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WifiNetwork wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null
    // Untyped, since the Bluetooth module does not declare these types to
    // tooling.
    readonly property var adapter: Bluetooth.defaultAdapter // qmllint disable unresolved-type
    readonly property var bluetoothDevice: adapter?.devices.values.find(d => d.connected) ?? null

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
        color: lit ? Qt.alpha(Theme.accent, 0.32) : entryHover.hovered ? Theme.panelHover : "transparent"

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
                color: entry.lit ? "#f0f2f4" : "#dadee3"
                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: entry.detail
                color: entry.lit ? "#a0a5ab" : "#94999e"
                font { family: Theme.font; pixelSize: 10 }
            }
        }
        Switch {
            visible: entry.switchable
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            checked: entry.on
            onToggled: entry.toggled()
        }
        HoverHandler {
            id: entryHover
        }
    }

    Entry {
        visible: panel.wired.length > 0
        title: "Ethernet"
        detail: panel.wiredConnected ? "Connected" : "Disconnected"
        lit: panel.wiredConnected

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1.5
            border.color: panel.wiredConnected ? Theme.accent : "#a3a8ae"
        }
    }

    Entry {
        visible: panel.wifi !== null
        title: "Wi-Fi"
        detail: !Networking.wifiEnabled ? "Off" : panel.wifiNetwork?.name ?? "Not connected"
        lit: panel.wifiNetwork !== null
        switchable: true
        on: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled

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
                    color: "#a3a8ae"
                }
            }
        }
    }

    Entry {
        visible: panel.adapter !== null
        title: "Bluetooth"
        detail: !panel.adapter?.enabled ? "Off" : panel.bluetoothDevice?.name ?? "On"
        lit: panel.bluetoothDevice !== null
        switchable: true
        on: panel.adapter?.enabled ?? false
        onToggled: panel.adapter.enabled = !panel.adapter.enabled

        Rectangle {
            anchors.centerIn: parent
            width: 9
            height: 9
            radius: 4.5
            color: "transparent"
            border.width: 1.5
            border.color: "#a3a8ae"
        }
    }

    Text {
        visible: panel.wired.length === 0 && panel.wifi === null && panel.adapter === null
        width: panel.panelWidth - 20
        padding: 10
        text: "No network devices"
        color: "#94999e"
        font { family: Theme.font; pixelSize: 12 }
    }
}
