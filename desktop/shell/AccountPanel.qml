// The account panel: who is signed in, on which computer, and the power
// actions. Lock and Settings come with the lock screen and Settings.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

BarPanel {
    id: panel

    readonly property string user: Quickshell.env("USER") ?? ""
    property string fullName
    readonly property string displayName: fullName || user

    // Run from a source tree (make run), the session is a window on the
    // developer's own desktop; powering off would end theirs.
    readonly property bool development: Quickshell.env("DESKTOP_SHELL") !== null

    function power(action: string) {
        dismissed();
        if (development)
            console.info("Not running", action, "in development");
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    panelWidth: 250

    // The full name is the first field of the account's comment.
    Process {
        command: ["getent", "passwd", panel.user]
        running: panel.user !== ""
        stdout: StdioCollector {
            onStreamFinished: panel.fullName = (text.split(":")[4] ?? "").split(",")[0]
        }
    }
    FileView {
        id: hostname
        path: "/etc/hostname"
    }

    Row {
        padding: 8
        spacing: 11

        Rectangle {
            width: 32
            height: 32
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: panel.displayName.charAt(0).toUpperCase()
                color: "#f5feff"
                font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: panel.displayName
                color: "#e7ecf0"
                font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                text: [panel.user, hostname.text().trim()].filter(s => s).join(" · ")
                color: "#94999e"
                font { family: Theme.mono; pixelSize: 10 }
            }
        }
    }

    Rectangle {
        width: panel.panelWidth - 20
        height: 1
        color: "#3b3d43"
    }

    Column {
        width: panel.panelWidth - 20
        spacing: 2

        Repeater {
            model: [
                { label: "Suspend", action: "suspend", icon: "M0.5 6h11" },
                { label: "Restart", action: "reboot", icon: "M10.6 3.4A5 5 0 1 1 6 1" },
                { label: "Shut down", action: "poweroff", icon: "M3.2 2.6a4.8 4.8 0 1 0 5.6 0M6 0.6v5" },
            ]

            Rectangle {
                id: entry

                required property var modelData

                width: parent.width
                height: 36
                color: entryHover.hovered ? Theme.panelHover : "transparent"

                Icon {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 11
                    gridWidth: 12
                    gridHeight: 12
                    strokeWidth: 1.5
                    color: "#a3a8ae"
                    strokes: entry.modelData.icon
                }
                Text {
                    x: 31
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label
                    color: "#c7cbd0"
                    font { family: Theme.font; pixelSize: 13 }
                }

                TapHandler {
                    onTapped: panel.power(entry.modelData.action)
                }
                HoverHandler {
                    id: entryHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
