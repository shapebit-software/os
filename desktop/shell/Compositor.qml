// Commands to the compositor, and what it reports beyond Quickshell's
// Hyprland module. Hyprland's configuration is Lua, so its dispatch requests
// are Lua too; Quickshell's own helpers, such as HyprlandWorkspace.activate(),
// still send the old syntax, which fails.
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: compositor

    // The layout of each workspace by id; a workspace not listed has the
    // default (compositor/layouts.lua).
    property var layouts: ({})

    function dispatch(lua: string) {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function focusWindow(address: string) {
        dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
    }

    function setGaps(gap: int) {
        dispatch(`function() hl.config({ general = { gaps_in = ${gap / 2}, gaps_out = ${gap} } }) end`);
    }

    function setScale(output: string, scale: real) {
        dispatch(`function() hl.monitor({ output = "${output}", mode = "preferred", position = "auto", scale = ${scale} }) end`);
    }

    function layoutOf(id: int): string {
        return layouts[id] ?? "lead";
    }

    function setLayout(id: int, layout: string) {
        dispatch(`function() layouts.set(${id}, "${layout}") end`);
    }

    // The compositor announces layouts as custom events: "layout <id> <name>".
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            if (event.name !== "custom")
                return;
            const [kind, id, layout] = event.data.split(" ");
            if (kind === "layout")
                compositor.layouts = Object.assign({}, compositor.layouts, { [id]: layout });
        }
    }

    Component.onCompleted: dispatch("function() layouts.report() end")
}
