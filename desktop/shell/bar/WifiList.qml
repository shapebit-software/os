// The Wi-Fi networks in reach (Connectivity.qml), in the network panel and in
// Welcome: each with its signal and a lock if it is secured. A click joins a
// network, a secured one first asking its password in its row; Enter joins,
// Escape folds it.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking
import qs.controls
import qs.services

Column {
    id: list

    // The network whose password is being typed, and the networks as they
    // were then, so that the rows hold still while it is typed.
    property string typing
    property var held: []
    readonly property var networks: typing ? held : Connectivity.networks
    property real listHeight: 290

    readonly property string lockIcon: "M3.2 7.5a.5.5 0 0 1 .5-.5h8.6a.5.5 0 0 1 .5.5v5.8a.5.5 0 0 1-.5.5H3.7a.5.5 0 0 1-.5-.5zM5.3 7V5a2.7 2.7 0 0 1 5.4 0v2"

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

    onVisibleChanged: {
        if (!visible)
            typing = "";
    }

    ListView {
        id: networkList

        width: list.width
        height: Math.min(contentHeight, list.listHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: list.visible ? list.networks : []

        delegate: Column {
            id: network

            required property WifiNetwork modelData
            readonly property var outcome: Connectivity.joins[modelData.name]
            readonly property bool typingHere: list.typing === modelData.name

            width: networkList.width

            ConnectionItem {
                width: parent.width
                title: network.modelData.name
                lit: network.modelData.connected
                failed: network.outcome?.error !== undefined
                // qmllint disable unresolved-type
                detail: network.outcome?.busy || network.modelData.state === NetworkState.Connecting ? "Connecting…"
                    : network.outcome?.error ?? (network.modelData.connected ? "Connected"
                    : network.modelData.known ? "Saved" : "")
                // qmllint enable unresolved-type
                onChosen: list.choose(network.modelData)

                SignalBars {
                    anchors.bottom: parent.bottom
                    strength: network.modelData.signalStrength
                    color: network.modelData.connected ? Theme.accent : Theme.inkSoft
                }
                end: Icon {
                    visible: ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.modelData.security) // qmllint disable unresolved-type
                    anchors.centerIn: parent
                    height: 11
                    color: Theme.inkFaint
                    strokes: list.lockIcon
                }
            }

            // The password, typed in the row.
            Item {
                visible: network.typingHere
                width: parent.width
                height: 40

                Rectangle {
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
                        onAccepted: list.submit(network.modelData, text)
                        Keys.onEscapePressed: list.typing = ""
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
                        onTapped: list.submit(network.modelData, password.text)
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
        visible: networkList.count === 0
        width: list.width
        leftPadding: 34
        topPadding: 6
        bottomPadding: 6
        text: "Looking for networks…"
        color: Theme.inkFaint
        font { family: Theme.font; pixelSize: 11 }
    }
}
