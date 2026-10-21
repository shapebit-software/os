// The strip of one screen, floating at the bottom: the Apps button, then a
// small map of each workspace's windows. A click on a map goes to that
// workspace, a click on a window in it focuses that window, and the wheel
// steps through them.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: scope

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    // This screen's workspaces in order; special workspaces have negative ids.
    readonly property list<HyprlandWorkspace> workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === monitor)
        .sort((a, b) => a.id - b.id)
    property bool appsOpen

    // Window positions come from the compositor on request, so ask again
    // after anything changes there.
    Connections {
        target: Hyprland
        function onRawEvent() { refresh.restart(); }
    }
    Timer {
        id: refresh
        interval: 30
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
        }
    }
    Component.onCompleted: refresh.start()

    PanelWindow {
        id: strip

        screen: scope.modelData
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "strip"
        anchors { bottom: true; left: true; right: true }
        // The tiles stop a gap above the strip; the compositor adds that gap.
        exclusiveZone: Theme.stripHeight + Theme.gap
        // The window reaches into that gap for the layout buttons.
        implicitHeight: Theme.stripHeight + 2 * Theme.gap
        color: "transparent"
        // Only the strip's content and the gap above it take input; the rest
        // of its band passes through.
        mask: Region {
            x: content.x
            width: content.width
            height: content.y + content.height
        }

        Row {
            id: content
            x: Theme.gap
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.gap
            spacing: 4

            AppsButton {
                open: scope.appsOpen
                onClicked: scope.appsOpen = !scope.appsOpen
            }

            Row {
                spacing: 4

                Repeater {
                    model: scope.workspaces

                    WorkspaceMap {
                        screen: scope.modelData
                        monitor: scope.monitor
                        onActivated: scope.appsOpen = false
                    }
                }

                WheelHandler {
                    property real lastStep

                    onWheel: event => {
                        const now = Date.now();
                        const delta = event.angleDelta.y || event.angleDelta.x;
                        if (now - lastStep < 260 || Math.abs(delta) < 4)
                            return;
                        lastStep = now;
                        const list = scope.workspaces;
                        const i = Math.max(0, list.indexOf(scope.monitor?.activeWorkspace));
                        const next = list[(i + (delta < 0 ? 1 : -1) + list.length) % list.length];
                        if (next)
                            Compositor.focusWorkspace(next.id);
                    }
                }
            }
        }
    }

    AppsPanel {
        screen: scope.modelData
        visible: scope.appsOpen
        // Clicks on the strip leave the panel open, so the Apps button can
        // close it.
        grabWindows: [strip]
        onDismissed: scope.appsOpen = false
    }
}
