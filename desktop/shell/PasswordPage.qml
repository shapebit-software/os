// A page of Settings to change the account's password: the current one, and
// the new one twice. systemd-homed changes it with the home's encryption, so
// the current password must be right; homectl takes both passwords from its
// environment, which only this account can read, not from its command line.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Column {
    id: page

    property string message
    property bool messageIsError
    readonly property bool busy: changer.running
    readonly property bool ready: current.text !== "" && next.text !== "" && repeated.text !== "" && !busy

    function change() {
        if (next.text !== repeated.text) {
            message = "The new passwords differ";
            messageIsError = true;
            return;
        }
        message = "";
        changer.environment = { PASSWORD: current.text, NEWPASSWORD: next.text };
        changer.running = true;
    }

    function clear() {
        for (const field of [current, next, repeated])
            field.text = "";
        message = "";
    }

    spacing: 14
    onVisibleChanged: {
        clear();
        if (visible)
            current.forceActiveFocus();
    }

    component Field: Rectangle {
        property alias text: input.text
        property alias placeholder: hint.text
        property Item next

        function forceActiveFocus() {
            input.forceActiveFocus();
        }

        width: 320
        height: 32
        color: "white"
        border.color: input.activeFocus ? Theme.accent : "#d1d5d8"

        TextInput {
            id: input

            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            enabled: !page.busy
            color: "#1d2022"
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 12 }
            clip: true
            onAccepted: {
                if (parent.next)
                    parent.next.forceActiveFocus();
                else if (page.ready)
                    page.change();
            }

            Text {
                id: hint
                visible: !input.text
                color: "#8a8f94"
                font: input.font
            }
        }
    }

    Field {
        id: current
        placeholder: "Current password"
        next: next
    }
    Field {
        id: next
        placeholder: "New password"
        next: repeated
    }
    Field {
        id: repeated
        placeholder: "New password again"
    }

    Text {
        height: 16
        text: page.busy ? "Changing…" : page.message
        color: page.messageIsError ? "#b63132" : "#44484d"
        font { family: Theme.font; pixelSize: 12 }
    }

    Rectangle {
        width: label.width + 28
        height: 32
        color: page.ready ? Theme.accent : "#c9cdd1"

        Text {
            id: label
            anchors.centerIn: parent
            text: "Change password"
            color: "white"
            font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
        }
        TapHandler {
            enabled: page.ready
            onTapped: page.change()
        }
        HoverHandler {
            cursorShape: page.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    Process {
        id: changer

        command: ["homectl", "passwd", Account.user]
        stderr: StdioCollector {
            id: errors
        }
        onRunningChanged: {
            if (running)
                return;
            // homectl says nothing on success; otherwise its first line says
            // why, such as "Password too weak: The password is shorter than
            // 8 characters".
            const error = errors.text.trim().split("\n")[0];
            if (error) {
                page.message = error.startsWith("Password incorrect") ? "The current password is wrong"
                    : error.startsWith("Password too weak: ") ? "Too weak: " + error.slice(19) : error;
                page.messageIsError = true;
            } else {
                page.clear();
                page.message = "Password changed";
                page.messageIsError = false;
            }
            changer.environment = {};
        }
    }
}
