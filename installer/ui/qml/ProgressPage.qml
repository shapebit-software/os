// Shows the phase the backend is in. Cancel is offered only while the disk
// is still untouched.
import QtQuick
import QtQuick.Layouts
import Installer

Step {
    id: page

    readonly property var phases: [
        { name: "validating", text: qsTr("Validating"), detail: qsTr("checking the plan and this computer") },
        { name: "preparing", text: qsTr("Preparing"), detail: qsTr("preparing; the disk is still untouched") },
        { name: "creating-storage", text: qsTr("Creating storage"), detail: qsTr("erasing the disk and creating encrypted storage") },
        { name: "installing-system", text: qsTr("Installing system"), detail: qsTr("writing ShapeBit image and boot entries") },
        { name: "configuring", text: qsTr("Configuring"), detail: qsTr("setting up the TPM, the recovery key, and your account") },
        { name: "verifying", text: qsTr("Verifying"), detail: qsTr("checking the installation") }
    ]
    readonly property int current: phases.findIndex(phase => phase.name === Backend.phase)
    readonly property bool destructive: current >= 2
    readonly property var tips: [
        qsTr("Each workspace keeps its own layout. Press Alt + 1–9 to switch between them."),
        qsTr("Updates install in the background and apply on the next restart."),
        qsTr("The disk is encrypted and unlocks by itself on this computer.")
    ]
    property int tip: 0

    number: 7
    label: qsTr("Installing")
    heading: qsTr("Installing ShapeBit")
    subtitle: qsTr("This usually takes a few minutes. Keep the computer plugged in.")
    contentWidth: 504
    backVisible: false
    nextVisible: !destructive
    nextKind: "secondary"
    nextText: qsTr("Cancel")
    onNext: Backend.cancel()

    Timer {
        interval: 12000
        running: true
        repeat: true
        onTriggered: page.tip = (page.tip + 1) % page.tips.length
    }

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
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -4
        Mono {
            Layout.fillWidth: true
            text: qsTr("Step %1 of %2").arg(Math.max(0, page.current) + 1).arg(page.phases.length)
            color: Theme.text
        }
        Mono {
            visible: page.destructive
            text: qsTr("Do not turn off the computer")
            color: Theme.muted
        }
    }
    Mono {
        Layout.alignment: Qt.AlignHCenter
        text: page.current < 0 ? "" : page.phases[page.current].detail
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        columns: 2
        columnSpacing: 20
        rowSpacing: 12

        Repeater {
            model: page.phases
            RowLayout {
                id: phase
                required property var modelData
                required property int index
                readonly property bool done: index < page.current
                readonly property bool active: index === page.current
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 10

                Rectangle {
                    implicitWidth: 10
                    implicitHeight: 10
                    color: phase.done ? Theme.accent : "transparent"
                    border.width: phase.active ? 2 : 1
                    border.color: phase.done || phase.active ? Theme.accent : Theme.faint
                }
                Text {
                    Layout.fillWidth: true
                    text: phase.modelData.text
                    color: phase.done || phase.active ? Theme.text : Theme.faint
                    font.pixelSize: 13
                    font.weight: phase.active ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    Panel {
        Layout.fillWidth: true
        Layout.topMargin: 12
        implicitHeight: tipText.implicitHeight + 28
        color: "transparent"

        Mono {
            id: tipLabel
            x: 15
            y: 15
            text: qsTr("TIP")
            color: Theme.link
            font.pixelSize: 9
        }
        Text {
            id: tipText
            anchors.left: tipLabel.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 15
            y: 14
            text: page.tips[page.tip]
            color: Theme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
