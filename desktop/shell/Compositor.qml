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
    // Where the window of an application that launch() opened goes, until it
    // opens or time runs out: { workspace, address, until }.
    property var placing: null

    function dispatch(lua: string) {
        Hyprland.dispatch(lua);
    }

    // A Lua string literal of text.
    function quote(text: string): string {
        return JSON.stringify(text).replace(/\\u([0-9a-fA-F]{4})/g, "\\u{$1}");
    }

    function focusWorkspace(id: int) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function focusWindow(address: string) {
        dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
    }

    function moveWindow(address: string, workspace: int) {
        dispatch(`hl.dsp.window.move({ workspace = ${workspace}, window = "address:0x${address}", follow = false })`);
        refresh.restart();
    }

    // Two windows change places, in their workspaces or between them.
    function swapWindows(address: string, other: string) {
        dispatch(`hl.dsp.window.swap({ window = "address:0x${address}", target = "address:0x${other}" })`);
        refresh.restart();
    }

    // Moves a workspace's windows and layout to another id, and shifts those
    // in between toward it (compositor/workspaces.lua).
    function moveWorkspace(from: int, to: int) {
        dispatch(`function() workspaces.move(${from}, ${to}) end`);
    }

    // Opens an application on a workspace and goes there. With a window's
    // address, the new window takes that window's place.
    function launch(app: DesktopEntry, workspace: int, address: string) {
        const shell = text => `'${text.replace(/'/g, "'\\''")}'`;
        const command = app.command.map(shell).join(" ");
        const directory = app.workingDirectory ? `cd ${shell(app.workingDirectory)} && ` : "";
        placing = { workspace, address, until: Date.now() + 15000 };
        dispatch(`hl.dsp.exec_cmd(${quote(directory + command)}, { workspace = "${workspace}" })`);
        focusWorkspace(workspace);
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

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent) {
            refresh.restart();
            if (event.name === "openwindow")
                compositor.place(event.data.split(","));
            // The compositor announces layouts as custom events:
            // "layout <id> <name>".
            if (event.name !== "custom")
                return;
            const [kind, id, layout] = event.data.split(" ");
            if (kind === "layout")
                compositor.layouts = Object.assign({}, compositor.layouts, { [id]: layout });
        }
    }

    // The first window to open after launch() is taken for the application's:
    // it goes to its workspace, in case the application did not start it
    // itself, and to its place there.
    function place([address, workspace]) {
        const target = placing;
        placing = null;
        if (!target || Date.now() > target.until)
            return;
        if (workspace !== String(target.workspace))
            moveWindow(address, target.workspace);
        if (target.address)
            swapWindows(address, target.address);
    }

    // Window positions and workspaces come from the compositor on request, so
    // ask again after anything changes there, including what this file asks for.
    Timer {
        id: refresh
        interval: 30
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Component.onCompleted: {
        dispatch("function() layouts.report() end");
        refresh.start();
    }
}
