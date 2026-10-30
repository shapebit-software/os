// The installer window: a header that shows where the user is, and one page
// at a time. The pages before the destructive confirmation are a stack the
// user can go back through; from then on, the backend's phase decides which
// page shows.
import QtQuick
import QtQuick.Controls.Basic
import Installer

ApplicationWindow {
    id: window

    readonly property int steps: 8
    readonly property Step page: stack.currentItem as Step

    visible: true
    width: 1280
    height: 800
    title: qsTr("Install ShapeBit")
    color: Theme.background

    // What the user chose. The password stays here only until it is sent.
    QtObject {
        id: plan
        property string locale
        property string keyboardLayout
        property string timeZone
        property string userName
        property string realName
        property string password
    }

    function show(phase) {
        switch (phase) {
        case "":
        case "idle":
            break
        case "awaiting-acknowledgement":
            stack.replace(null, recoveryKeyPage)
            break
        case "completed":
            stack.replace(null, donePage)
            break
        case "failed":
            stack.replace(null, errorPage)
            break
        default:
            if (!(stack.currentItem instanceof ProgressPage))
                stack.replace(null, progressPage)
        }
    }

    function startOver() {
        plan.password = ""
        Backend.refresh()
        stack.replace(null, Backend.available ? welcomePage : errorPage)
    }

    Connections {
        target: Backend
        function onPhaseChanged() { window.show(Backend.phase) }
    }

    // A faint glow at the top and the bottom of the dark background.
    Rectangle {
        width: parent.width
        height: parent.height * 0.3
        gradient: Gradient {
            GradientStop { position: 0; color: "#1b1630" }
            GradientStop { position: 1; color: Theme.background }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.22
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.background }
            GradientStop { position: 1; color: "#221519" }
        }
    }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 30 }
        height: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Logo { size: 20 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ShapeBit"
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }
        // One dash for each step; the current one is longer.
        Row {
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: window.steps
                Rectangle {
                    required property int index
                    readonly property int number: window.page ? window.page.number : 1
                    width: index + 1 === number ? 24 : 10
                    height: 3
                    color: index < number ? Theme.accent : Theme.border
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Mono {
                text: window.page ? String(window.page.number).padStart(2, "0") + " / " + String(window.steps).padStart(2, "0") : ""
                font.pixelSize: 9
            }
            Mono {
                text: window.page ? window.page.label : ""
                color: Theme.muted
                font.pixelSize: 9
            }
        }
    }

    StackView {
        id: stack
        objectName: "stack"
        // The keyboard works from the first page on, before anything is clicked.
        focus: true
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        initialItem: Backend.available ? welcomePage : errorPage
        Component.onCompleted: window.show(Backend.phase)

        // Pages fade into one another; nothing slides.
        pushEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
        popEnter: pushEnter
        popExit: pushExit
        replaceEnter: pushEnter
        replaceExit: pushExit
    }

    Component {
        id: welcomePage
        WelcomePage {
            onNext: {
                plan.locale = locale
                stack.push(keyboardPage)
            }
        }
    }
    Component {
        id: keyboardPage
        KeyboardPage {
            onBack: stack.pop()
            onNext: {
                plan.keyboardLayout = layout
                stack.push(networkPage)
            }
        }
    }
    Component {
        id: networkPage
        NetworkPage {
            onBack: stack.pop()
            onNext: stack.push(timeZonePage)
        }
    }
    Component {
        id: timeZonePage
        TimeZonePage {
            onBack: stack.pop()
            onNext: {
                plan.timeZone = timeZone
                stack.push(accountPage)
            }
        }
    }
    Component {
        id: accountPage
        AccountPage {
            onBack: stack.pop()
            onNext: {
                plan.userName = userName
                plan.realName = realName
                plan.password = password
                stack.push(diskPage)
            }
        }
    }
    Component {
        id: diskPage
        DiskPage {
            onBack: stack.pop()
            // The destructive confirmation.
            onNext: {
                const started = Backend.install({
                    disk: selected.id, userName: plan.userName, realName: plan.realName,
                    locale: plan.locale, keyboardLayout: plan.keyboardLayout, timeZone: plan.timeZone
                }, plan.password)
                plan.password = ""
                if (!started)
                    stack.replace(null, errorPage)
            }
        }
    }
    Component { id: progressPage; ProgressPage {} }
    Component { id: recoveryKeyPage; RecoveryKeyPage {} }
    Component { id: donePage; DonePage {} }
    Component { id: errorPage; ErrorPage { onNext: window.startOver() } }
}
