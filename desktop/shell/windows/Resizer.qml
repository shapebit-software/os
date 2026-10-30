// The handles that resize the tiles of the workspace on one screen, as in
// the demo: in the space between two columns or two cells, lighter under the
// pointer; dragged, they move the line between them (Compositor.splits).
pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: resizer

    required property ShellScreen modelData

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property HyprlandWorkspace workspace: monitor?.activeWorkspace ?? null
    readonly property var splits: workspace ? Compositor.splits[workspace.id] ?? [] : []
    // How thick the handles are: the gap, but easy to catch.
    readonly property int thickness: Math.max(Theme.gap, 8)

    screen: modelData
    visible: splits.length > 0 && !(workspace?.hasFullscreen ?? false)
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "resizer"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // Only the handles take input.
    mask: Region {
        regions: resizer.regions
    }
    property list<Region> regions

    // A place for each handle, as Region needs.
    Instantiator {
        model: resizer.splits

        Region {
            required property var modelData
            readonly property rect place: resizer.placeOf(modelData)

            x: place.x
            y: place.y
            width: place.width
            height: place.height
        }

        onObjectAdded: (index, object) => resizer.regions = [...resizer.regions, object]
        onObjectRemoved: (index, object) => resizer.regions = resizer.regions.filter(r => r !== object)
    }

    // A handle's place on this screen.
    function placeOf(split: var): rect {
        const x = split.x - (monitor?.x ?? 0), y = split.y - (monitor?.y ?? 0);
        return split.kind === "c" ? Qt.rect(x - thickness / 2, y, thickness, split.length)
            : Qt.rect(x, y - thickness / 2, split.length, thickness);
    }

    Item {
        id: handles

        anchors.fill: parent

        // By number, so a handle stays while it moves, and keeps being dragged.
        Repeater {
            model: resizer.splits.length

            Rectangle {
                id: handle

                required property int index
                readonly property var modelData: resizer.splits[index] ?? { kind: "c", x: 0, y: 0, length: 0 }
                readonly property bool down: modelData.kind === "c"
                readonly property rect place: resizer.placeOf(modelData)

                x: place.x
                y: place.y
                width: place.width
                height: place.height
                color: area.containsMouse || area.pressed ? Qt.rgba(1, 1, 1, 0.22) : "transparent"

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: handle.down ? Qt.SizeHorCursor : Qt.SizeVerCursor
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        const at = handle.down
                            ? handle.x + mouse.x + (resizer.monitor?.x ?? 0)
                            : handle.y + mouse.y + (resizer.monitor?.y ?? 0);
                        Compositor.resize(resizer.workspace.id, handle.modelData.kind,
                            handle.modelData.column, handle.modelData.cell, at);
                    }
                }
            }
        }
    }
}
