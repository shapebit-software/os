// The installation is complete.
import QtQuick
import Installer

Step {
    objectName: "done"
    number: 8
    heading: qsTr("ShapeBit is installed")
    subtitle: qsTr("Remove the USB drive, then restart.")
    backVisible: false
    nextText: qsTr("Restart now")
    onNext: Backend.reboot()
}
