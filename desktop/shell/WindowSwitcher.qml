// The window switcher on one screen (Switcher.qml): a row of the windows,
// each with its application's icon, its title, and the place of its
// workspace on the strip; the picked one in the accent, and lit on its map.
// Tab and the arrows go through them, Enter or letting go of Alt focuses
// the picked one, Q closes it, a click focuses one, and Escape cancels.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: window

    required property ShellScreen modelData

    readonly property bool here: Switcher.open && Switcher.screen === (modelData?.name ?? "")

    // The place of a workspace on its screen's strip, counted from 1.
    function placeOf(workspace: HyprlandWorkspace): int {
        return Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor === workspace?.monitor && w.toplevels.values.length > 0)
            .sort((a, b) => a.id - b.id)
            .indexOf(workspace) + 1;
    }

    visible: here
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "switcher"
    WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    onHereChanged: {
        if (here)
            keys.forceActiveFocus();
    }

    // A click off the windows cancels.
    MouseArea {
        anchors.fill: parent
        onClicked: Switcher.close()
    }

    Item {
        id: keys

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                Switcher.close();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Switcher.done();
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                Switcher.step(1, false);
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                Switcher.step(-1, false);
            else if (event.key === Qt.Key_Q)
                Switcher.closePicked();
            else
                return;
            event.accepted = true;
        }
        // Alt let go, in case the compositor's word comes after.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                Switcher.done();
        }
    }

    PopoverFrame {
        anchors.centerIn: parent
        opacity: Switcher.shown ? 1 : 0
        padding: 12

        Flow {
            width: Math.min(Switcher.windows.length * 132, window.width * 0.8)
            spacing: 8

            Repeater {
                model: Switcher.windows

                Rectangle {
                    id: tile

                    required property HyprlandToplevel modelData
                    required property int index
                    readonly property bool picked: Switcher.index === index
                    readonly property DesktopEntry entry: {
                        void DesktopEntries.applications.values;
                        const cls = modelData.lastIpcObject.class;
                        return cls ? DesktopEntries.heuristicLookup(cls) : null;
                    }

                    width: 124
                    height: 118
                    radius: Theme.rounded ? 7 : 0
                    color: picked ? Theme.accentSoft : hover.hovered ? Theme.veil(0.06) : "transparent"
                    border.width: picked ? 2 : 0
                    border.color: Theme.accent

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        implicitSize: 44
                        source: Quickshell.iconPath(tile.entry?.icon ?? "", "application-x-executable")
                    }
                    Text {
                        x: 8
                        y: 66
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: tile.modelData.title || tile.entry?.name || tile.modelData.lastIpcObject.class || ""
                        color: Theme.ink
                        font { family: Theme.font; pixelSize: 11; weight: tile.picked ? Font.DemiBold : Font.Medium }
                    }
                    // The place of its workspace on the strip.
                    Text {
                        anchors { right: parent.right; top: parent.top; margins: 6 }
                        text: window.placeOf(tile.modelData.workspace) || ""
                        color: Theme.inkFaint
                        font { family: Theme.mono; pixelSize: 10; weight: Font.DemiBold }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Switcher.pick(tile.index)
                    }
                }
            }
        }
    }
}
