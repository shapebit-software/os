// The strip of one screen, floating at the bottom: the Apps button, then a
// small map of each workspace's windows, and the quick actions in the corner. A click on a map goes to that
// workspace, a click on a window in it focuses that window, and the wheel
// steps through them. Windows, applications from Apps, and workspaces can be
// dragged onto the maps (WorkspaceMap.qml); while a window or an application
// is dragged, a "+" after the maps makes a new workspace for it. Workspaces
// without windows go away (compositor/workspaces.lua).
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
    property bool captureOpen
    // The most workspaces the "+" makes, as in the demo.
    readonly property int maxWorkspaces: 8

    // Opens the dragged application, or moves the dragged window, to a new
    // workspace after all others, and goes there.
    function dropOnNew() {
        const id = Math.max(0, ...Hyprland.workspaces.values.map(w => w.id)) + 1;
        if (Dragging.app) {
            Compositor.launch(Dragging.app, id, "");
        } else if (Dragging.window) {
            Compositor.moveWindow(Dragging.window.address, id);
            Compositor.focusWorkspace(id);
        }
        Dragging.clear();
        appsOpen = false;
    }

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
        // Only the strip's content, the gap above it, and the quick actions
        // take input; the rest of its band passes through.
        mask: Region {
            x: content.x
            width: content.width
            height: content.y + content.height

            Region { item: quickActions }
        }

        QuickActions {
            id: quickActions
            anchors.right: parent.right
            anchors.rightMargin: Theme.gap
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.gap
            onCaptureClicked: scope.captureOpen = !scope.captureOpen
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

                // The "+", where a drop makes a new workspace.
                Rectangle {
                    visible: Dragging.tile && scope.workspaces.length < scope.maxWorkspaces
                    width: 84
                    height: Theme.stripHeight
                    color: Qt.rgba(1, 1, 1, newDrop.containsDrag ? 0.2 : 0.08)
                    border.width: newDrop.containsDrag ? 2 : 1
                    border.color: newDrop.containsDrag ? Theme.accent : Qt.rgba(1, 1, 1, 0.3)

                    Icon {
                        anchors.centerIn: parent
                        height: 12
                        gridWidth: 12
                        gridHeight: 12
                        strokeWidth: 1.6
                        strokes: "M6 1v10M1 6h10"
                        color: "#f6f9fb"
                        opacity: newDrop.containsDrag ? 1 : 0.7
                    }

                    DropArea {
                        id: newDrop
                        anchors.fill: parent
                        onDropped: scope.dropOnNew()
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

    CapturePanel {
        screen: scope.modelData
        visible: scope.captureOpen
        grabWindows: [strip]
        onDismissed: scope.captureOpen = false
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
