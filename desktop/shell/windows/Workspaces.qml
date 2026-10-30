// The workspaces on a bar (ShellBar.qml): a small map of each workspace's
// windows (WorkspaceMap.qml), in order along the bar. A click on a map goes to
// that workspace, and the wheel steps through them. Windows, applications
// from Apps, and workspaces can be dragged onto the maps; while a window or
// an application is dragged, a "+" after the maps makes a new workspace for
// it. Workspaces without windows go away (compositor/workspaces.lua).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.bar
import qs.controls
import qs.services

GridLayout {
    id: strip

    required property ShellBar bar

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.modelData)
    // This screen's workspaces in order; special workspaces have negative ids.
    readonly property list<HyprlandWorkspace> workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor === monitor)
        .sort((a, b) => a.id - b.id)
    // The most workspaces the "+" makes, as in the demo.
    readonly property int maxWorkspaces: 8
    // A map's size: as wide as the screen's shape across a bar, as wide as
    // the bar along a side.
    readonly property int mapWidth: bar.vertical ? bar.size : Math.round(bar.size * 1.4)
    readonly property int mapHeight: bar.vertical ? Math.round(bar.size / 1.4) : bar.size

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
        Shell.close();
    }

    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 4
    columnSpacing: 4

    Repeater {
        model: strip.workspaces

        WorkspaceMap {
            // A workspace without windows has no map, but while something is
            // dragged it takes drops.
            visible: windows.length > 0 || Dragging.tile
            bar: strip.bar
            monitor: strip.monitor
            implicitWidth: strip.mapWidth
            implicitHeight: strip.mapHeight
            onActivated: Shell.close()
        }
    }

    // The "+", where a drop makes a new workspace.
    Rectangle {
        visible: Dragging.tile && strip.workspaces.length < strip.maxWorkspaces
        implicitWidth: strip.mapWidth
        implicitHeight: strip.mapHeight
        radius: Theme.rounded ? 2.5 : 0
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
            onDropped: strip.dropOnNew()
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
            const list = strip.workspaces;
            const i = Math.max(0, list.indexOf(strip.monitor?.activeWorkspace));
            const next = list[(i + (delta < 0 ? 1 : -1) + list.length) % list.length];
            if (next)
                Compositor.focusWorkspace(next.id);
        }
    }
}
