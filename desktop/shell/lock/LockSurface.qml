// What a screen shows while the session is locked, laid out like the login
// screen: the date and the system menus along the top, and in the middle who
// is signed in and the password field.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Colors
import Quickshell
import qs.controls
import qs.services

Item {
    id: surface

    // "Large text" in the accessibility menu scales every size.
    property real unit: 1
    property bool reveal
    property string openMenu

    // The first letters of the first two words: "Alex Rivera" is "AR".
    readonly property string initials: Account.displayName.split(/\s+/).filter(word => word !== "").slice(0, 2)
        .map(word => word[0].toUpperCase()).join("")

    function power(action: string) {
        // Run from a source tree (make run), the session is a window on the
        // developer's own desktop; powering off would end theirs.
        if (Quickshell.env("DESKTOP_SHELL") !== null)
            console.info("Not running", action, "in development");
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    function submit() {
        Lock.unlock(password.text);
        password.text = "";
    }

    component IconButton: Rectangle {
        id: button

        property string path
        property real iconSize: 18 * surface.unit
        property color fill: "transparent"

        signal clicked()

        implicitWidth: 30 * surface.unit
        implicitHeight: 30 * surface.unit
        color: fill.a > 0 ? fill : area.containsMouse ? Theme.dark.hover : "transparent"

        Icon {
            anchors.centerIn: parent
            height: button.iconSize
            gridWidth: 24
            gridHeight: 24
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            color: Theme.dark.textStrong
            strokes: button.path
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // A menu that opens under its button.
    component Menu: Rectangle {
        id: menu

        property var entries: []

        z: 2
        width: column.width + 2
        height: column.height + 2
        color: Theme.dark.surface
        border.color: Theme.dark.line

        Column {
            id: column
            x: 1
            y: 1

            Repeater {
                model: menu.entries

                Rectangle {
                    id: row

                    required property var modelData

                    width: 180 * surface.unit
                    height: 38 * surface.unit
                    color: rowArea.containsMouse ? Theme.dark.hover : "transparent"

                    Text {
                        x: 14 * surface.unit
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text
                        color: Theme.dark.textStrong
                        font { family: Theme.font; pixelSize: 14 * surface.unit }
                    }
                    Text {
                        visible: row.modelData.checked === true
                        anchors { right: parent.right; rightMargin: 12 * surface.unit; verticalCenter: parent.verticalCenter }
                        text: "✓"
                        color: Theme.dark.textStrong
                        font { family: Theme.font; pixelSize: 14 * surface.unit }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            surface.openMenu = "";
                            row.modelData.run();
                        }
                    }
                }
            }
        }
    }

    Backdrop {
        anchors.fill: parent
    }

    // The click that closes an open menu.
    MouseArea {
        anchors.fill: parent
        z: 1
        visible: surface.openMenu !== ""
        onClicked: surface.openMenu = ""
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        x: 14 * surface.unit
        height: 44 * surface.unit
        spacing: 8 * surface.unit

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(clock.date, "ddd d MMM")
            color: Theme.dark.textMuted
            font { family: Theme.font; pixelSize: 13 * surface.unit }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(clock.date, Settings.timePattern)
            color: Theme.dark.textStrong
            font { family: Theme.font; pixelSize: 13 * surface.unit; weight: Font.DemiBold }
        }
        // How many notifications wait, never what they say.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.all.length > 0
            text: Notifications.all.length === 1 ? "· 1 notification" : `· ${Notifications.all.length} notifications`
            color: Theme.dark.textMuted
            font { family: Theme.font; pixelSize: 13 * surface.unit }
        }
    }

    IconButton {
        id: powerButton
        anchors { right: parent.right; rightMargin: 12 * surface.unit }
        y: 7 * surface.unit
        path: "M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0"
        onClicked: surface.openMenu = surface.openMenu === "power" ? "" : "power"
    }
    Menu {
        visible: surface.openMenu === "power"
        anchors { right: powerButton.right; top: powerButton.bottom; topMargin: 4 * surface.unit }
        entries: [
            { text: "Suspend", run: () => surface.power("suspend") },
            { text: "Restart", run: () => surface.power("reboot") },
            { text: "Shut down", run: () => surface.power("poweroff") }
        ]
    }
    // The input language.
    Item {
        id: language
        anchors { right: powerButton.left; rightMargin: 10 * surface.unit; verticalCenter: powerButton.verticalCenter }
        width: 22 * surface.unit
        height: width

        Icon {
            anchors.fill: parent
            gridWidth: 24
            gridHeight: 24
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            color: Theme.dark.textStrong
            strokes: "M4 3h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-9l-4 4v-4H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"
        }
        Text {
            x: (parent.width - width) / 2
            y: parent.height * 0.395 - height / 2
            text: Keyboard.code.substring(0, 2).toUpperCase()
            color: Theme.dark.textStrong
            font { family: Theme.font; pixelSize: 8 * surface.unit; weight: Font.Bold }
        }
    }
    IconButton {
        id: accessibilityButton
        anchors { right: language.left; rightMargin: 8 * surface.unit; verticalCenter: powerButton.verticalCenter }
        path: "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20zM12 6.6a.6.6 0 1 0 0 1.2a.6.6 0 1 0 0-1.2z"
            + "M7.5 10.2l4.5 1l4.5-1M12 11.2v3.3l-2.3 3.6M12 14.5l2.3 3.6"
        onClicked: surface.openMenu = surface.openMenu === "accessibility" ? "" : "accessibility"
    }
    Menu {
        visible: surface.openMenu === "accessibility"
        anchors { right: accessibilityButton.right; top: accessibilityButton.bottom; topMargin: 4 * surface.unit }
        entries: [{ text: "Large text", checked: surface.unit > 1, run: () => surface.unit = surface.unit > 1 ? 1 : 1.25 }]
    }

    Avatar {
        id: avatar
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -94 * surface.unit }
        width: 100 * surface.unit
        height: width
        round: true
        letters: surface.initials
        lettersScale: 0.34
        border { color: Theme.sheen(0.25); width: Math.max(1, width / 40) }
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: avatar.verticalCenter; verticalCenterOffset: 82 * surface.unit }
        text: Account.displayName
        color: Theme.dark.textStrong
        font { family: Theme.font; pixelSize: 20 * surface.unit; weight: Font.DemiBold }
    }

    // The password field, with its button.
    Rectangle {
        id: field

        anchors { verticalCenter: avatar.verticalCenter; verticalCenterOffset: 144 * surface.unit; left: parent.horizontalCenter; leftMargin: -173 * surface.unit }
        width: 299 * surface.unit
        height: 44 * surface.unit
        color: Theme.dark.surfaceSunken
        border.color: Lock.messageIsError ? Theme.dark.danger : Theme.dark.line
        opacity: Lock.checking ? 0.6 : 1

        TextInput {
            id: password

            anchors { left: parent.left; right: parent.right; leftMargin: 14 * surface.unit; rightMargin: 44 * surface.unit; verticalCenter: parent.verticalCenter }
            echoMode: surface.reveal ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            enabled: !Lock.checking
            focus: true
            color: Theme.dark.textStrong
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 15 * surface.unit }
            clip: true
            onAccepted: surface.submit()

            Text {
                visible: !password.text
                text: Lock.checking ? "Checking…" : "Password"
                color: Theme.dark.textMuted
                font: password.font
            }
        }
        // Shows or hides the typed password.
        IconButton {
            anchors { right: parent.right; rightMargin: 7 * surface.unit; verticalCenter: parent.verticalCenter }
            iconSize: 16 * surface.unit
            path: "M2 12s3.6-7 10-7s10 7 10 7s-3.6 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6z"
                + (surface.reveal ? "M4 4l16 16" : "")
            onClicked: surface.reveal = !surface.reveal
        }
    }
    IconButton {
        anchors { left: field.right; verticalCenter: field.verticalCenter }
        width: 47 * surface.unit
        height: field.height
        fill: Theme.accent
        opacity: Lock.checking ? 0.6 : 1
        path: "M5 12h14M13 6l6 6l-6 6"
        onClicked: surface.submit()
    }
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: field.bottom; topMargin: 12 * surface.unit }
        text: Lock.message
        color: Lock.messageIsError ? Theme.dark.danger : Theme.dark.textMuted
        font { family: Theme.font; pixelSize: 13 * surface.unit }
    }

    // A screen that is shown takes the keyboard for the field.
    Component.onCompleted: password.forceActiveFocus()
}
