// Commands to the compositor. Hyprland's configuration is Lua, so its
// dispatch requests are Lua too; Quickshell's own helpers, such as
// HyprlandWorkspace.activate(), still send the old syntax, which fails.
pragma Singleton
import Quickshell
import Quickshell.Hyprland

Singleton {
    function dispatch(lua: string) {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function focusWindow(address: string) {
        dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
    }
}
