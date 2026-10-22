// The account panel, as in the demo: who is signed in and on which computer,
// with a button for Settings, then tiles to lock, suspend, restart, and shut
// down.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
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

    panelWidth: 252

    // Who, and Settings.
    Item {
        width: panel.panelWidth - 2 * panel.padding
        height: 58

        Avatar {
            id: avatar
            x: 6
            y: 6
            width: 40
            height: 40
            round: true
        }
        Column {
            x: avatar.x + avatar.width + 12
            anchors.verticalCenter: avatar.verticalCenter
            width: parent.width - x - settingsButton.width - 4
            spacing: 3

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Account.displayName
                color: Theme.ink
                font { family: Theme.font; pixelSize: 14; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: [Account.user, Account.hostname].filter(s => s).join(" · ")
                color: Theme.inkFaint
                font { family: Theme.mono; pixelSize: 10 }
            }
        }
        Rectangle {
            id: settingsButton

            anchors.right: parent.right
            anchors.verticalCenter: avatar.verticalCenter
            width: 32
            height: 32
            color: settingsHover.hovered ? Theme.veil(0.08) : "transparent"

            // A gear.
            Icon {
                anchors.centerIn: parent
                height: 16
                color: Theme.ink
                strokes: "M3.4 8a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0-9.2 0zM6.2 8a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0-3.6 0z"
            }
            Icon {
                anchors.centerIn: parent
                height: 16
                strokeWidth: 2.2
                color: Theme.ink
                strokes: "M12.6 8L14.3 8M11.25 11.25L12.45 12.45M8 12.6L8 14.3M4.75 11.25L3.55 12.45"
                    + "M3.4 8L1.7 8M4.75 4.75L3.55 3.55M8 3.4L8 1.7M11.25 4.75L12.45 3.55"
            }

            TapHandler {
                onTapped: panel.openSettings("account")
            }
            HoverHandler {
                id: settingsHover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    // The actions.
    Grid {
        columns: 2
        spacing: 4

        Repeater {
            model: [
                { label: "Lock", action: "lock", icon: "M3.2 7.5a.5.5 0 0 1 .5-.5h8.6a.5.5 0 0 1 .5.5v5.8a.5.5 0 0 1-.5.5H3.7a.5.5 0 0 1-.5-.5zM5.3 7V5a2.7 2.7 0 0 1 5.4 0v2" },
                { label: "Suspend", action: "suspend", icon: "M12.8 9.6A5.4 5.4 0 1 1 6.4 3.2a4.3 4.3 0 0 0 6.4 6.4z" },
                { label: "Restart", action: "reboot", icon: "M13 8a5 5 0 1 1-1.5-3.6M11.8 1.8v2.8H9" },
                { label: "Shut down", action: "poweroff", icon: "M8 1.8v5.6M4.6 4a5.2 5.2 0 1 0 6.8 0" },
            ]

            Rectangle {
                id: tile

                required property var modelData

                width: (panel.panelWidth - 2 * panel.padding - 4) / 2
                height: 58
                color: Theme.veil(tileHover.hovered ? 0.1 : 0.05)

                Column {
                    anchors.centerIn: parent
                    spacing: 7

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 16
                        capStyle: ShapePath.RoundCap
                        color: Theme.ink
                        strokes: tile.modelData.icon
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }
                    }
                }

                TapHandler {
                    onTapped: {
                        if (tile.modelData.action === "lock") {
                            panel.dismissed();
                            Lock.lock();
                        } else {
                            panel.power(tile.modelData.action);
                        }
                    }
                }
                HoverHandler {
                    id: tileHover
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
