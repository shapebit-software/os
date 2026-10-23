// The question for an administrator's password (Authorization.qml), in the
// lock screen's style, over the focused screen: what is asked and why, the
// password field, and Cancel. Enter answers; Escape cancels.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen modelData

    visible: Authorization.asking && (Hyprland.focusedMonitor?.name ?? "") === (modelData?.name ?? "")
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "authorization"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onVisibleChanged: {
        if (visible) {
            password.text = "";
            password.forceActiveFocus();
        }
    }

    // As on the lock screen: the backdrop, dimmed.
    Backdrop {
        anchors.fill: parent
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.1, 0.08, 0.16, 0.42)
        focus: true
        Keys.onEscapePressed: Authorization.cancel()
    }

    Column {
        anchors.centerIn: parent
        width: 340
        spacing: 14

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            capStyle: ShapePath.RoundCap
            color: Theme.text
            strokes: "M3.2 7.5a.5.5 0 0 1 .5-.5h8.6a.5.5 0 0 1 .5.5v5.8a.5.5 0 0 1-.5.5H3.7a.5.5 0 0 1-.5-.5zM5.3 7V5a2.7 2.7 0 0 1 5.4 0v2"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Authentication required"
            color: Theme.text
            font { family: Theme.font; pixelSize: 18; weight: Font.DemiBold }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Authorization.flow?.message ?? ""
            color: Theme.text
            opacity: 0.72
            font { family: Theme.font; pixelSize: 13 }
        }

        // The password field, as on the lock screen.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 38
            radius: 15
            color: Qt.rgba(1, 1, 1, 0.14)
            border.color: Authorization.failed ? Theme.danger : Qt.rgba(1, 1, 1, 0.22)
            opacity: Authorization.flow?.isResponseRequired ? 1 : 0.6

            TextInput {
                id: password

                anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
                anchors.verticalCenter: parent.verticalCenter
                echoMode: Authorization.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                enabled: Authorization.flow?.isResponseRequired ?? false
                color: Theme.text
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 14; letterSpacing: 1 }
                clip: true
                Keys.onEscapePressed: Authorization.cancel()

                onAccepted: {
                    Authorization.submit(text);
                    text = "";
                }

                Text {
                    visible: !password.text
                    // polkit asks "Password:"; another administrator's is named.
                    text: !password.enabled ? "Checking…"
                        : Authorization.ownPassword || !Authorization.identity ? "Password"
                        : `Password for ${Authorization.identity.displayName || Authorization.identity.string}`
                    color: Theme.text
                    opacity: 0.6
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 16
            text: Authorization.failed ? "Wrong password" : Authorization.flow?.supplementaryMessage ?? ""
            color: Authorization.failed || Authorization.flow?.supplementaryIsError ? Theme.danger : Theme.text
            font { family: Theme.font; pixelSize: 12 }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 34
            radius: 15
            color: Qt.rgba(1, 1, 1, cancelHover.hovered ? 0.2 : 0.12)

            Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.text
                font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
            }

            TapHandler {
                onTapped: Authorization.cancel()
            }
            HoverHandler {
                id: cancelHover
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
