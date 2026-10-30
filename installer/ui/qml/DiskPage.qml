// Choose the disk and confirm that it will be erased: the last page before
// the installation. Disks that cannot be a target are listed with the reason.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    id: page

    property var selected: null
    readonly property bool supported: Backend.capabilities.uefi === true && Backend.capabilities.tpm2 === true

    function size(disk) {
        const gb = disk.size / 1e9
        return gb >= 1000 ? (gb / 1000).toFixed(gb % 1000 === 0 ? 0 : 1) + " TB" : gb.toFixed(0) + " GB"
    }
    function kind(disk) {
        const transport = disk.transport === "nvme" ? "NVMe" : disk.transport.toUpperCase()
        return (disk.transport === "usb" || disk.removable ? qsTr("External %1") : qsTr("Internal %1")).arg(transport)
    }
    function name(disk) {
        return disk.model || qsTr("Disk")
    }

    number: 6
    label: qsTr("Disk")
    heading: qsTr("Choose a disk")
    subtitle: qsTr("ShapeBit uses the whole disk. Choose where to install it.")
    contentWidth: 536
    nextText: qsTr("Erase disk and install ShapeBit")
    nextKind: "danger"
    nextEnabled: supported && selected !== null && understood.checked
    // A confirmation covers the disk it was given for.
    onSelectedChanged: understood.checked = false

    Text {
        visible: !page.supported
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: Theme.danger
        font.pixelSize: 13
        text: qsTr("ShapeBit needs a machine that starts in UEFI mode and has a TPM 2.0.")
    }

    Panel {
        Layout.fillWidth: true
        implicitHeight: Math.max(disks.implicitHeight + 2, 60)

        Column {
            id: disks
            objectName: "disks"
            x: 1
            y: 1
            width: parent.width - 2

            Repeater {
                model: Backend.disks

                ListRow {
                    id: entry
                    required property var modelData
                    width: disks.width
                    implicitHeight: 54
                    leftPadding: 14
                    rightPadding: 14
                    enabled: modelData.eligible
                    // Reachable with Tab; Space chooses.
                    focusPolicy: Qt.StrongFocus
                    chosen: page.selected !== null && page.selected.id === modelData.id
                    onClicked: page.selected = modelData

                    contentItem: RowLayout {
                        spacing: 12
                        Rectangle {
                            implicitWidth: 13
                            implicitHeight: 13
                            radius: 7
                            color: entry.chosen ? Theme.accent : "transparent"
                            border.color: entry.chosen ? Theme.accent : Theme.muted
                            Rectangle {
                                anchors.centerIn: parent
                                visible: entry.chosen
                                width: 5
                                height: 5
                                radius: 3
                                color: Theme.text
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Row {
                                spacing: 9
                                Text {
                                    text: page.name(entry.modelData)
                                    color: Theme.text
                                    font.pixelSize: Theme.body
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    anchors.baseline: parent.children[0].baseline
                                    text: page.kind(entry.modelData)
                                    color: Theme.muted
                                    font.pixelSize: 12
                                }
                            }
                            // The identity the backend erases by, and where the disk is now.
                            Mono {
                                font.pixelSize: 9
                                text: entry.modelData.eligible
                                    ? entry.modelData.id + " · " + entry.modelData.path : entry.modelData.reason
                            }
                        }
                        Mono {
                            text: page.size(entry.modelData)
                            color: Theme.text
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: Backend.disks.length === 0
            text: qsTr("No disks found.")
            color: Theme.faint
            font.pixelSize: 13
        }
    }

    Panel {
        Layout.fillWidth: true
        implicitHeight: confirmation.implicitHeight + 28
        color: "transparent"

        RowLayout {
            id: confirmation
            x: 15
            y: 14
            width: parent.width - 30
            spacing: 10

            Check {
                id: understood
                objectName: "understood"
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                enabled: page.selected !== null
            }
            Column {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    width: parent.width
                    text: qsTr("I understand that all data on this disk will be deleted")
                    color: Theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    TapHandler {
                        enabled: understood.enabled
                        onTapped: understood.toggle()
                    }
                }
                Text {
                    width: parent.width
                    text: page.selected === null ? qsTr("Choose a disk first.")
                        : qsTr("Everything on %1 (%2) will be permanently removed. This can’t be undone.")
                            .arg(page.name(page.selected)).arg(page.size(page.selected))
                    color: Theme.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
    LinkButton {
        Layout.alignment: Qt.AlignRight
        text: qsTr("Look for disks again")
        onClicked: {
            page.selected = null
            Backend.refresh()
        }
    }
}
