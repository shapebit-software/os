// Shows the phase the backend is in. Cancel is offered only while the disk
// is still untouched.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    id: page

    readonly property var phases: [
        { name: "validating", text: qsTr("Checking this computer") },
        { name: "preparing", text: qsTr("Preparing; the disk is still untouched") },
        { name: "creating-storage", text: qsTr("Erasing the disk and creating encrypted storage") },
        { name: "installing-system", text: qsTr("Writing the system") },
        { name: "configuring", text: qsTr("Setting up the TPM, the recovery key, and your account") },
        { name: "verifying", text: qsTr("Checking the installation") }
    ]
    readonly property int current: phases.findIndex(phase => phase.name === Backend.phase)
    readonly property bool destructive: current >= 2

    number: 7
    heading: qsTr("Installing ShapeBit")
    subtitle: qsTr("This usually takes a few minutes. Keep the computer plugged in and turned on.")
    contentWidth: 504
    backVisible: false
    nextVisible: !destructive
    nextKind: "secondary"
    nextText: qsTr("Cancel")
    onNext: Backend.cancel()

    // The backend reports phases, not a percentage: the bar shows the phases done.
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 6
        color: Theme.track
        Rectangle {
            width: parent.width * Math.max(0, page.current) / page.phases.length
            height: parent.height
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        // Moves while the current phase is at work.
        Rectangle {
            id: pulse
            width: 40
            height: parent.height
            color: Theme.link
            opacity: 0.6
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: pulse.parent.width - pulse.width; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: pulse.parent.width - pulse.width; to: 0; duration: 1800; easing.type: Easing.InOutSine }
            }
        }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: page.current < 0 ? "" : page.phases[page.current].text
        color: Theme.muted
        font.pixelSize: 13
    }
}
