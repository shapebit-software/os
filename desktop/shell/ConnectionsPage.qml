// A page of Settings for the Wi-Fi networks or the Bluetooth devices, as the
// network panel lists them (Connectivity.qml), each with what can be done:
// joining a network, a secured one with its password typed in its row, and
// disconnecting or forgetting it; pairing, connecting, disconnecting, or
// forgetting a device. While it shows, the computer looks for more.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking

Column {
    id: page

    // "wifi" or "bluetooth".
    property string kind
    // The network whose password is being typed, and the networks as they
    // were then, so that the rows hold still while it is typed.
    property string typing
    property var held: []
    readonly property var entries: kind === "wifi" ? (typing ? held : Connectivity.networks) : Connectivity.devices

    spacing: 22

    // Its kind and whether it shows change apart, in either order.
    onVisibleChanged: Qt.callLater(look)
    onKindChanged: Qt.callLater(look)

    function look() {
        typing = "";
        Connectivity.scan(visible && kind === "wifi", visible && kind === "bluetooth");
    }

    function networkDetail(network: WifiNetwork): string {
        const outcome = Connectivity.joins[network.name];
        if (outcome?.busy || network.state === NetworkState.Connecting) // qmllint disable unresolved-type
            return "Connecting…";
        if (outcome?.error)
            return outcome.error;
        if (network.connected)
            return "Connected";
        if (network.known)
            return "Saved";
        return [WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security) ? "Open" : "Secured"; // qmllint disable unresolved-type
    }

    function deviceDetail(device: var): string {
        const outcome = Connectivity.pairs[device.dbusPath];
        return outcome?.busy || device.pairing ? "Pairing…"
            : outcome?.error ?? (device.connected ? (device.batteryAvailable
                ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected")
                : device.paired ? "Paired" : "Nearby");
    }

    // The actions of an entry, by label, each what it does.
    function actions(entry: var): var {
        if (kind === "wifi") {
            return [
                ...(entry.connected ? [["Disconnect", () => entry.disconnect()]]
                    : [["Join", () => join(entry)]]),
                ...(entry.known ? [["Forget", () => entry.forget()]] : []),
            ];
        }
        return [
            ...(entry.paired ? [[entry.connected ? "Disconnect" : "Connect", () => Connectivity.use(entry)],
                ["Forget", () => entry.forget()]] : [["Pair", () => Connectivity.use(entry)]]),
        ];
    }

    function join(network: WifiNetwork) {
        if (Connectivity.needsPassword(network)) {
            held = Connectivity.networks;
            typing = typing === network.name ? "" : network.name;
        } else {
            Connectivity.join(network, "");
        }
    }

    Rectangle {
        width: page.width
        height: list.height + 2
        color: "white"
        border.color: "#d8dbde"

        Column {
            id: list

            x: 1
            y: 1
            width: parent.width - 2

            Repeater {
                model: page.entries

                Column {
                    id: entry

                    required property var modelData
                    required property int index
                    readonly property bool typingHere: page.kind === "wifi" && page.typing === modelData.name
                    readonly property string detail: page.kind === "wifi" ? page.networkDetail(modelData) : page.deviceDetail(modelData)

                    width: list.width

                    Item {
                        width: parent.width
                        height: 52

                        Rectangle {
                            visible: entry.index > 0
                            width: parent.width
                            height: 1
                            color: "#e6e8ea"
                        }
                        Column {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - actions.width - 32

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: entry.modelData.name
                                color: "#1d2022"
                                font { family: Theme.font; pixelSize: 13; weight: entry.modelData.connected ? Font.Medium : Font.Normal }
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                text: entry.detail
                                color: (page.kind === "wifi" ? Connectivity.joins[entry.modelData.name]
                                    : Connectivity.pairs[entry.modelData.dbusPath])?.error !== undefined ? "#b63132" : "#65696f"
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                        Row {
                            id: actions

                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 18

                            Repeater {
                                model: page.actions(entry.modelData)

                                Text {
                                    required property var modelData

                                    text: modelData[0]
                                    color: modelData[0] === "Forget" ? "#b63132" : Theme.accent
                                    font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

                                    TapHandler {
                                        onTapped: parent.modelData[1]()
                                    }
                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }
                    }

                    // The password, typed in the row; Enter joins, Escape
                    // folds it.
                    Item {
                        visible: entry.typingHere
                        width: parent.width
                        height: 48

                        Rectangle {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(320, parent.width - 120)
                            height: 32
                            color: "white"
                            border.color: "#d1d5d8"

                            TextInput {
                                id: password

                                anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                                anchors.verticalCenter: parent.verticalCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                color: "#1d2022"
                                selectionColor: Theme.accent
                                font { family: Theme.font; pixelSize: 12 }
                                clip: true
                                onAccepted: submit()
                                Keys.onEscapePressed: page.typing = ""

                                function submit() {
                                    if (!text)
                                        return;
                                    Connectivity.join(entry.modelData, text);
                                    page.typing = "";
                                }

                                Text {
                                    visible: !password.text
                                    text: "Password"
                                    color: "#65696f"
                                    font: password.font
                                }
                            }
                        }
                        Text {
                            x: Math.min(320, parent.width - 120) + 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Join"
                            color: Theme.accent
                            opacity: password.text ? 1 : 0.45
                            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

                            TapHandler {
                                onTapped: password.submit()
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
                visible: page.entries.length === 0
                width: list.width
                padding: 16
                text: page.kind === "wifi" ? "Looking for networks…" : "Looking for devices…"
                color: "#65696f"
                font { family: Theme.font; pixelSize: 12 }
            }
        }
    }
}
