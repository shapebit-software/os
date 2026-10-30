// Shows the device recovery key once. The installation completes only when
// the user confirms that it is saved.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    id: page

    property string recoveryKey

    number: 8
    label: qsTr("Recovery key")
    heading: qsTr("Save your recovery key")
    subtitle: qsTr("This computer unlocks its disk by itself. If that ever fails, for example after a hardware repair, only this key unlocks it.")
    contentWidth: 536
    backVisible: false
    nextText: qsTr("Finish")
    nextEnabled: saved.checked && recoveryKey !== ""
    onNext: {
        recoveryKey = ""
        Backend.acknowledge()
    }
    Component.onCompleted: recoveryKey = Backend.takeRecoveryKey()

    Panel {
        Layout.fillWidth: true
        implicitHeight: key.implicitHeight + 40

        Text {
            id: key
            objectName: "recoveryKey"
            x: 20
            y: 20
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
            text: page.recoveryKey
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 18
            lineHeight: 1.4
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Write it down or photograph it, and keep it away from this computer. It is not shown again. Anyone who has the key can read the disk, and ShapeBit cannot restore a lost key.")
        color: Theme.muted
        font.pixelSize: 12
        lineHeight: 1.3
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 10
        Check {
            id: saved
            objectName: "saved"
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("I saved my recovery key outside this computer")
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            TapHandler { onTapped: saved.toggle() }
        }
    }
}
