// The installation is complete.
import QtQuick
import Installer

Step {
    number: 8
    label: qsTr("Finish")
    heading: qsTr("ShapeBit is installed")
    subtitle: qsTr("Remove the USB drive, then restart to start using your new system.")
    backVisible: false
    nextText: qsTr("Restart now")
    onNext: Backend.reboot()
}
