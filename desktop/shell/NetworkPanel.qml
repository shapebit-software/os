// The network panel: wired, Wi-Fi, and Bluetooth, each when the computer has
// it. The connection in use is lit; Wi-Fi and Bluetooth have switches. A
// click on Wi-Fi or Bluetooth unfolds what is in reach (Connectivity.qml):
// the networks, in use first, then known, then by signal (WifiList.qml), each with its
// signal and a lock if it is secured; or the devices, paired first, then those
// nearby. A click on a network joins it, a secured one first asking its
// password in its row; a click on a device pairs it, connects it, or
// disconnects it. Forgetting is in Settings > Network.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking

BarPanel {
    id: panel

    // The list unfolded: "wifi", "bluetooth", or none.
    property string unfolded

    function unfold(list: string) {
        unfolded = unfolded === list ? "" : list;
        wifiList.typing = "";
    }

    spacing: 2

    onVisibleChanged: {
        if (!visible)
            unfolded = "";
    }
    onUnfoldedChanged: Connectivity.scan(unfolded === "wifi", unfolded === "bluetooth")

    component Entry: Rectangle {
        id: entry

        property string title
        property string detail
        property bool lit
        property bool switchable
        property bool on
        // Whether a click unfolds a list, and whether it is unfolded.
        property bool unfoldable
        property bool unfolded
        default property alias icon: iconHolder.data
        signal toggled
        signal unfold

        width: panel.panelWidth - 20
        height: 46
        color: lit ? Theme.accentSoft : entryHover.hovered && unfoldable ? Theme.veil(0.07) : "transparent"

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
            width: parent.width - x - (entry.switchable ? 50 : 10) - (entry.unfoldable ? 16 : 0)

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
        Icon {
            visible: entry.unfoldable
            anchors.right: parent.right
            anchors.rightMargin: entry.switchable ? 50 : 10
            anchors.verticalCenter: parent.verticalCenter
            height: 10
            rotation: entry.unfolded ? 90 : 0
            color: Theme.inkFaint
            strokes: "M6 3.5l4.5 4.5L6 12.5"
        }
        // The row but its switch unfolds the list.
        Item {
            visible: entry.unfoldable
            width: parent.width - (entry.switchable ? 50 : 0)
            height: parent.height

            TapHandler {
                onTapped: entry.unfold()
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
        Switch {
            visible: entry.switchable
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            on: entry.on
            onToggled: entry.toggled()
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
        unfoldable: Networking.wifiEnabled
        unfolded: panel.unfolded === "wifi"
        onToggled: Connectivity.toggleWifi()
        onUnfold: panel.unfold("wifi")

        SignalBars {
            anchors.bottom: parent.bottom
        }
    }

    // The networks in reach.
    WifiList {
        id: wifiList

        visible: panel.unfolded === "wifi" && Networking.wifiEnabled
        width: panel.panelWidth - 20
    }

    Entry {
        visible: Connectivity.adapter !== null
        title: "Bluetooth"
        detail: Connectivity.bluetoothDetail
        lit: Connectivity.bluetoothDevice !== null
        switchable: true
        on: Connectivity.adapter?.enabled ?? false
        unfoldable: Connectivity.adapter?.enabled ?? false
        unfolded: panel.unfolded === "bluetooth"
        onToggled: Connectivity.toggleBluetooth()
        onUnfold: panel.unfold("bluetooth")

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

    // The devices: paired, then nearby.
    ListView {
        id: deviceList

        visible: panel.unfolded === "bluetooth" && (Connectivity.adapter?.enabled ?? false)
        width: panel.panelWidth - 20
        height: Math.min(contentHeight, 290)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? Connectivity.devices : []

        delegate: ConnectionItem {
            id: device

            required property var modelData
            readonly property var outcome: Connectivity.pairs[modelData.dbusPath]

            width: deviceList.width
            title: modelData.name
            lit: modelData.connected
            failed: outcome?.error !== undefined
            detail: outcome?.busy || modelData.pairing ? "Pairing…"
                : outcome?.error ?? (modelData.connected
                    ? (modelData.batteryAvailable ? `Connected · ${Math.round(modelData.battery * 100)}%` : "Connected")
                    : modelData.paired ? "Paired" : "")
            onChosen: Connectivity.use(modelData)

            Rectangle {
                anchors.centerIn: parent
                width: 9
                height: 9
                radius: 4.5
                color: device.modelData.connected ? Theme.accent : "transparent"
                border.width: 1.5
                border.color: device.modelData.connected ? Theme.accent : Theme.inkSoft
            }
        }
    }
    Text {
        visible: deviceList.visible && deviceList.count === 0
        width: panel.panelWidth - 20
        leftPadding: 34
        topPadding: 6
        bottomPadding: 6
        text: "Looking for devices…"
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 11 }
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
