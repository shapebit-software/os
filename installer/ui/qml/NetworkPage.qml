// Offer a Wi-Fi connection. It is optional: the installation needs none.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    id: page

    property string selected // SSID
    readonly property bool connected: Backend.networks.some(network => network.connected)

    function connect(ssid, password) {
        if (Backend.connectNetwork(ssid, password))
            selected = ""
    }

    number: 3
    label: qsTr("Network")
    heading: qsTr("Connect to a network")
    subtitle: qsTr("A connection is optional. You can also connect after setup.")
    nextText: connected ? qsTr("Continue") : qsTr("Skip for now")
    Component.onCompleted: Backend.refreshNetworks()

    Panel {
        Layout.fillWidth: true
        implicitHeight: Math.max(list.implicitHeight + 2, 90)

        Column {
            id: list
            x: 1
            y: 1
            width: parent.width - 2

            Repeater {
                model: Backend.networks

                Column {
                    id: entry
                    required property var modelData
                    readonly property bool open: page.selected === modelData.ssid && !modelData.connected
                    width: list.width

                    ListRow {
                        width: parent.width
                        implicitHeight: 44
                        chosen: entry.open || entry.modelData.connected
                        // Reachable with Tab; Space opens.
                        focusPolicy: Qt.StrongFocus
                        onClicked: page.selected = entry.open ? "" : entry.modelData.ssid

                        contentItem: RowLayout {
                            spacing: 12
                            // Signal strength, as four bars.
                            Row {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 3
                                        height: 3 + index * 3
                                        y: 12 - height
                                        color: entry.modelData.strength > index * 25 ? Theme.text : Theme.faint
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.ssid
                                color: Theme.text
                                font.pixelSize: Theme.body
                                elide: Text.ElideRight
                            }
                            Mono {
                                text: entry.modelData.connected ? qsTr("Connected") : entry.modelData.security || qsTr("Open")
                                color: entry.modelData.connected ? Theme.link : Theme.faint
                                font.pixelSize: 9
                            }
                        }
                    }
                    RowLayout {
                        visible: entry.open
                        x: 12
                        width: parent.width - 24
                        height: 54
                        spacing: 10
                        // Enter in the password connects; it does not leave the page.
                        Keys.onReturnPressed: if (connect.enabled) connect.clicked()
                        Keys.onEnterPressed: if (connect.enabled) connect.clicked()

                        Field {
                            id: password
                            objectName: "wifiPassword"
                            Layout.fillWidth: true
                            visible: entry.modelData.security !== ""
                            echoMode: TextInput.Password
                            placeholderText: qsTr("Password")
                            onVisibleChanged: if (visible) forceActiveFocus()
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: entry.modelData.security === ""
                            text: qsTr("Others can see what you send over an open network.")
                            color: Theme.muted
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                        Btn {
                            id: connect
                            objectName: "connect"
                            implicitHeight: 38
                            text: qsTr("Connect")
                            enabled: entry.modelData.security === "" || password.text !== ""
                            onClicked: page.connect(entry.modelData.ssid, password.text)
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: Backend.networks.length === 0
            text: qsTr("No Wi-Fi networks found.")
            color: Theme.faint
            font.pixelSize: 13
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            objectName: "networkError"
            Layout.fillWidth: true
            text: Backend.error
            color: Theme.danger
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        LinkButton {
            text: qsTr("Look again")
            onClicked: Backend.refreshNetworks()
        }
    }
}
