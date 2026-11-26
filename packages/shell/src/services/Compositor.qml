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
    // The windows of each workspace by id, in the order its layout fills its
    // cells, and the one Tabs or Accordion shows: { order: [address],
    // shown: address or "" }, addresses as Quickshell has them.
    property var tiles: ({})
    // Where each workspace's tiles can be resized, by id: lines between
    // columns { kind: "c", column, cell: 0, x, y, length } running down, and
    // between cells { kind: "r", column, cell, x, y, length } running across,
    // in the compositor's coordinates (compositor/layouts.lua).
    property var splits: ({})
    // Where the window of an application that launch() opened goes, until it
    // opens or time runs out: { workspace, address, until }.
    property var placing: null

    // A keyboard shortcut for the shell, by name, and the list of every
    // shortcut, as "<keys>|<description>;..." (compositor/shortcuts.lua).
    signal shortcut(name: string)
    signal shortcutList(list: string)

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

    function closeWindow(address: string) {
        dispatch(`hl.dsp.window.close({ window = "address:0x${address}" })`);
    }

    // Puts a window in full screen, or ends that, as Alt+F does.
    function toggleFullscreen(address: string) {
        focusWindow(address);
        dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", window = "address:0x${address}" })`);
    }

    // Ends full screen on a workspace.
    function exitFullscreen(workspace: int) {
        dispatch(`function()
            local window = hl.get_workspace(${workspace}).fullscreen_window
            if window then
                hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", window = "address:" .. window.address }))
            end
        end`);
    }

    function moveWindow(address: string, workspace: int) {
        dispatch(`hl.dsp.window.move({ workspace = ${workspace}, window = "address:0x${address}", follow = false })`);
        refresh.restart();
    }

    // Moves a window to the workspace shown on another screen.
    function moveWindowToScreen(address: string, screen: string) {
        dispatch(`hl.dsp.window.move({ monitor = ${quote(screen)}, window = "address:0x${address}", follow = false })`);
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

    // The look of the tiles (Settings.windowCorners, windowDecoration), as
    // in the demo: a hairline is a thin dark border, a shadow lifts the tile,
    // and soft corners are slightly rounded with both, the border lighter.
    function setDecoration(corners: string, decoration: string) {
        const rounding = corners === "Rounded" ? 9 : decoration === "Soft" ? 4 : 0;
        const border = decoration === "Hairline" ? "rgba(0b08127a)" : decoration === "Soft" ? "rgba(ffffff14)" : "";
        const shadow = decoration === "Shadow" || decoration === "Soft";
        dispatch(`function() hl.config({
            general = { border_size = ${border ? 1 : 0}, col = { active_border = "${border || "rgba(00000000)"}", inactive_border = "${border || "rgba(00000000)"}" } },
            decoration = { rounding = ${rounding}, shadow = { enabled = ${shadow}, range = 18, render_power = 2, offset = "0 6", color = "rgba(05030a38)" } },
        }) end`);
    }

    // The layout of new workspaces (compositor/layouts.lua).
    function setDefaultLayout(layout: string) {
        dispatch(`function() layouts.setDefault(${quote(layout)}) end`);
    }

    // The keyboard layouts to switch between, by code.
    function setKeyboards(codes: list<string>) {
        dispatch(`function() hl.config({ input = { kb_layout = ${quote(codes.join(","))} } }) end`);
    }

    // Moves a line between tiles of a workspace to a position on the screen
    // (compositor/layouts.lua).
    function resize(workspace: int, kind: string, column: int, cell: int, at: real) {
        dispatch(`function() layouts.resize(${workspace}, "${kind}", ${column}, ${cell}, ${Math.round(at)}) end`);
    }

    function layoutOf(id: int): string {
        return layouts[id] ?? Settings.defaultLayout;
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
            // The compositor announces layouts as custom events: "layout <id>
            // <name>", "tiles <id> <shown> <windows>", and "splits <id> <splits>";
            // and shortcuts: "shortcut <name>" and "shortcuts <list>".
            if (event.name !== "custom")
                return;
            const [kind, id, value, windows] = event.data.split(" ");
            if (kind === "shortcut")
                compositor.shortcut(id);
            else if (kind === "shortcuts")
                compositor.shortcutList(event.data.slice(kind.length + 1));
            const address = a => a.replace(/^0x/, "");
            if (kind === "layout")
                compositor.layouts = Object.assign({}, compositor.layouts, { [id]: value });
            else if (kind === "splits")
                compositor.splits = Object.assign({}, compositor.splits, { [id]: value === "-" ? []
                    : value.split(";").map(split => {
                        const [kind, column, cell, x, y, length] = split.split(",");
                        return { kind, column: +column, cell: +cell, x: +x, y: +y, length: +length };
                    }) });
            else if (kind === "tiles")
                compositor.tiles = Object.assign({}, compositor.tiles, { [id]: {
                    shown: value === "-" ? "" : address(value),
                    order: (windows ?? "").split(",").filter(a => a).map(address)
                } });
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
