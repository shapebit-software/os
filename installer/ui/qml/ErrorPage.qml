// The installation failed, or the backend cannot be reached.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    number: Backend.available ? 7 : 1
    label: qsTr("Problem")
    heading: Backend.available ? qsTr("The installation failed") : qsTr("The installer is not ready")
    subtitle: Backend.available
        ? qsTr("If the disk was already erased, it has no usable system. Starting over erases it again.") : ""
    backVisible: false
    nextText: Backend.available ? qsTr("Start over") : qsTr("Try again")

    Panel {
        Layout.fillWidth: true
        implicitHeight: message.implicitHeight + 30
        visible: Backend.error !== ""

        Mono {
            id: message
            objectName: "error"
            x: 15
            y: 15
            width: parent.width - 30
            wrapMode: Text.WordWrap
            text: Backend.error
            color: Theme.text
            font.pixelSize: 12
        }
    }
}
