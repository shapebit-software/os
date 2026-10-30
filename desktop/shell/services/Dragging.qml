// What is being dragged to the strip's maps (WorkspaceMap.qml), if anything:
// an application from Apps, a window from a map, or a workspace by its layout
// button. The drag itself is the platform's, so it crosses the shell's windows
// and the compositor draws the picture under the pointer.
pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    property DesktopEntry app
    property HyprlandToplevel window
    // A workspace's id, or 0.
    property int workspace

    // Something that lands in a cell of a map: an application or a window.
    readonly property bool tile: app !== null || window !== null

    function clear() {
        app = null;
        window = null;
        workspace = 0;
    }
}
