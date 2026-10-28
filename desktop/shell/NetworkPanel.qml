// The network panel: wired, Wi-Fi, and Bluetooth, each when the computer has
// it. The connection in use is lit; Wi-Fi and Bluetooth have switches. A
// click on Wi-Fi or Bluetooth unfolds what is in reach (Connectivity.qml):
// the networks, in use first, then known, then by signal, each with its
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
    // The network whose password is being typed, and the networks as they
    // were then, so that the rows hold still while it is typed.
    property string typing
    property var held: []
    readonly property var networks: typing ? held : Connectivity.networks

    readonly property string lockIcon: "M3.2 7.5a.5.5 0 0 1 .5-.5h8.6a.5.5 0 0 1 .5.5v5.8a.5.5 0 0 1-.5.5H3.7a.5.5 0 0 1-.5-.5zM5.3 7V5a2.7 2.7 0 0 1 5.4 0v2"

    function unfold(list: string) {
        unfolded = unfolded === list ? "" : list;
        typing = "";
    }

    // Joins a network; a secured one asks its password first.
    function choose(network: WifiNetwork) {
        if (network.connected)
            return;
        if (Connectivity.needsPassword(network)) {
            held = Connectivity.networks;
            typing = typing === network.name ? "" : network.name;
        } else {
            Connectivity.join(network, "");
        }
    }

    function submit(network: WifiNetwork, password: string) {
        if (!password)
            return;
        Connectivity.join(network, password);
        typing = "";
    }

    spacing: 2

    onVisibleChanged: {
        if (!visible) {
            unfolded = "";
            typing = "";
        }
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

    // The bars of a Wi-Fi signal, as many lit as it is strong, of three.
    component Bars: Row {
        id: bars

        property real strength: 1
        property color color: Theme.inkFaint

        spacing: 1.5

        Repeater {
            model: [4, 7, 11]

            Rectangle {
                required property int modelData
                required property int index
                anchors.bottom: parent.bottom
                width: 2
                height: modelData
                color: bars.color
                opacity: bars.strength > index / 3 ? 1 : 0.3
            }
        }
    }

    // A network or a device in an unfolded list.
    component ListItem: Rectangle {
        id: item

        property string title
        property string detail
        property bool lit
        property bool failed
        default property alias icon: itemIcon.data
        property alias end: endHolder.data
        signal chosen

        width: panel.panelWidth - 20
        height: 36
        color: lit ? Theme.accentSoft : itemHover.hovered ? Theme.veil(0.06) : "transparent"

        Item {
            id: itemIcon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 11
            height: 11
        }
        Column {
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 30

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: item.title
                color: Theme.ink
                font { family: Theme.font; pixelSize: 12; weight: item.lit ? Font.Medium : Font.Normal }
            }
            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: item.detail
                color: item.failed ? Theme.danger : Theme.inkFaint
                font { family: Theme.font; pixelSize: 10 }
            }
        }
        Item {
            id: endHolder
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 11
        }
        TapHandler {
            onTapped: item.chosen()
        }
        HoverHandler {
            id: itemHover
            cursorShape: Qt.PointingHandCursor
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

        Bars {
            anchors.bottom: parent.bottom
        }
    }

    // The networks in reach.
    ListView {
        id: networkList

        visible: panel.unfolded === "wifi" && Networking.wifiEnabled
        width: panel.panelWidth - 20
        height: Math.min(contentHeight, 290)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? panel.networks : []

        delegate: Column {
            id: network

            required property WifiNetwork modelData
            readonly property var outcome: Connectivity.joins[modelData.name]
            readonly property bool typingHere: panel.typing === modelData.name

            width: networkList.width

            ListItem {
                title: network.modelData.name
                lit: network.modelData.connected
                failed: network.outcome?.error !== undefined
                // qmllint disable unresolved-type
                detail: network.outcome?.busy || network.modelData.state === NetworkState.Connecting ? "Connecting…"
                    : network.outcome?.error ?? (network.modelData.connected ? "Connected"
                    : network.modelData.known ? "Saved" : "")
                // qmllint enable unresolved-type
                onChosen: panel.choose(network.modelData)

                Bars {
                    anchors.bottom: parent.bottom
                    strength: network.modelData.signalStrength
                    color: network.modelData.connected ? Theme.accent : Theme.inkSoft
                }
                end: Icon {
                    visible: ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.modelData.security) // qmllint disable unresolved-type
                    anchors.centerIn: parent
                    height: 11
                    color: Theme.inkFaint
                    strokes: panel.lockIcon
                }
            }

            // The password, typed in the row; Enter joins, Escape folds it.
            Item {
                visible: network.typingHere
                width: parent.width
                height: 40

                Rectangle {
                    id: field

                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - joinButton.width - 16
                    height: 28
                    color: Theme.veil(0.06)

                    TextInput {
                        id: password

                        anchors { left: parent.left; right: parent.right; leftMargin: 9; rightMargin: 9 }
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.ink
                        selectionColor: Theme.accent
                        font { family: Theme.font; pixelSize: 12 }
                        clip: true
                        onAccepted: panel.submit(network.modelData, text)
                        Keys.onEscapePressed: panel.typing = ""
                        Component.onCompleted: {
                            if (network.typingHere)
                                forceActiveFocus();
                        }

                        Text {
                            visible: !password.text
                            text: "Password"
                            color: Theme.inkFaint
                            font: password.font
                        }
                    }
                }
                Rectangle {
                    id: joinButton

                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: joinLabel.width + 20
                    height: 28
                    color: Theme.accent
                    opacity: password.text ? 1 : 0.45

                    Text {
                        id: joinLabel
                        anchors.centerIn: parent
                        text: "Join"
                        color: "white"
                        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                    }
                    TapHandler {
                        onTapped: panel.submit(network.modelData, password.text)
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                onVisibleChanged: {
                    if (visible) {
                        password.text = "";
                        password.forceActiveFocus();
                    }
                }
            }
        }
    }
    Text {
        visible: networkList.visible && networkList.count === 0
        width: panel.panelWidth - 20
        leftPadding: 34
        topPadding: 6
        bottomPadding: 6
        text: "Looking for networks…"
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 11 }
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

        delegate: ListItem {
            id: device

            required property var modelData
            readonly property var outcome: Connectivity.pairs[modelData.dbusPath]

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
