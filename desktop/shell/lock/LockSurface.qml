// What a screen shows while the session is locked: the backdrop dimmed, the
// time, who is signed in, and the password field.
import QtQuick
import Quickshell
import qs.controls
import qs.services
import qs.wallpaper

Item {
    id: surface

    Backdrop {
        anchors.fill: parent
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.1, 0.08, 0.16, 0.42)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, Settings.timePattern)
            color: Theme.text
            font { family: Theme.font; pixelSize: 84; weight: Font.DemiBold; letterSpacing: -2 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, Settings.longDatePattern)
            color: Theme.text
            opacity: 0.72
            font { family: Theme.font; pixelSize: 15; weight: Font.Medium }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.56
        spacing: 14

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56
            height: 56
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Account.displayName
            color: Theme.text
            font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
        }

        // The password field.
        Rectangle {
            width: 280
            height: 38
            radius: 15
            color: Qt.rgba(1, 1, 1, 0.14)
            border.color: Lock.messageIsError ? Theme.danger : Qt.rgba(1, 1, 1, 0.22)
            opacity: Lock.checking ? 0.6 : 1

            TextInput {
                id: password

                anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                enabled: !Lock.checking
                focus: true
                color: Theme.text
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 14; letterSpacing: 1 }
                clip: true

                onAccepted: {
                    Lock.unlock(text);
                    text = "";
                }

                Text {
                    visible: !password.text
                    text: Lock.checking ? "Checking…" : "Password"
                    color: Theme.text
                    opacity: 0.6
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 16
            text: Lock.message
            color: Lock.messageIsError ? Theme.danger : Theme.text
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    // A screen that is shown takes the keyboard for the field.
    Component.onCompleted: password.forceActiveFocus()
}
