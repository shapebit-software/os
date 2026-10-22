// The account panel: who is signed in and on which computer, Settings,
// locking, and the power actions.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

BarPanel {
    id: panel

    // Run from a source tree (make run), the session is a window on the
    // developer's own desktop; powering off would end theirs.
    readonly property bool development: Quickshell.env("DESKTOP_SHELL") !== null

    function power(action: string) {
        dismissed();
        // Whoever wakes the computer finds it locked.
        if (action === "suspend")
            Lock.lock();
        if (development)
            console.info("Not running", action, "in development");
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    function openSettings(section: string) {
        dismissed();
        Settings.open(screenName, section);
    }

    panelWidth: 250

    // Who: opens the account's settings.
    Rectangle {
        width: panel.panelWidth - 20
        height: who.height
        color: whoHover.hovered ? Theme.panelHover : "transparent"

        TapHandler {
            onTapped: panel.openSettings("account")
        }
        HoverHandler {
            id: whoHover
            cursorShape: Qt.PointingHandCursor
        }

        Row {
            id: who
            padding: 8
            spacing: 11

            Avatar {
                width: 32
                height: 32
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Account.displayName
                    color: "#e7ecf0"
                    font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
                }
                Text {
                    text: [Account.user, Account.hostname].filter(s => s).join(" · ")
                    color: "#94999e"
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }
        }
    }

    // Settings.
    Rectangle {
        width: panel.panelWidth - 20
        height: 36
        color: settingsHover.hovered ? Theme.panelHover : "transparent"

        Icon {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 12
            gridWidth: 12
            gridHeight: 12
            color: "#a3a8ae"
            strokes: "M0.5 2.5h11M0.5 6h11M0.5 9.5h11"
            fills: "M7 1h3v3H7zM2 4.5h3v3H2zM6 8h3v3H6z"
        }
        Text {
            x: 31
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            color: "#dadee3"
            font { family: Theme.font; pixelSize: 13 }
        }

        TapHandler {
            onTapped: panel.openSettings("appearance")
        }
        HoverHandler {
            id: settingsHover
            cursorShape: Qt.PointingHandCursor
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
                { label: "Lock", action: "lock", icon: "M4 5.5V3.6a2 2 0 0 1 4 0v1.9M2.5 5.5h7v5.5h-7z" },
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
                    onTapped: {
                        if (entry.modelData.action === "lock") {
                            panel.dismissed();
                            Lock.lock();
                        } else {
                            panel.power(entry.modelData.action);
                        }
                    }
                }
                HoverHandler {
                    id: entryHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
