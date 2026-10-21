-- The compositor configuration of ShapeBit Desktop (Hyprland, Lua).
-- The session starts Hyprland with this file (see session/desktop.desktop);
-- people's own settings do not live here.

-- The shell draws the wallpaper, the bar, and every panel. DESKTOP_SHELL
-- points at a source tree during development (see the Makefile).
local shell = os.getenv("DESKTOP_SHELL") or "/usr/share/desktop/shell"

hl.on("hyprland.start", function()
    hl.exec_cmd("qs --path " .. shell)
end)

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- In a window on another desktop (make run), the automatic scale guesses too
-- high; the host desktop scales the window already.
hl.monitor({
    output   = "WAYLAND-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Windows are plain tiles: straight corners, no border, no shadow, and one
-- gap everywhere. Blur is only for the shell's glass (the layer rules below);
-- tiles are opaque, so nothing shows through them.
local gap = 10

hl.config({
    general = {
        gaps_in     = gap / 2,
        gaps_out    = gap,
        border_size = 0,
        layout      = "master",
    },

    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = true },
    },

    master = {
        new_status = "slave",
    },

    misc = {
        -- The shell owns the background.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- Workspaces stay when they empty, like the demo's; it starts with five.
-- Adding and removing them comes with Overview.
for id = 1, 5 do
    hl.workspace_rule({ workspace = tostring(id), persistent = true })
end

-- The bar and Apps are glass.
hl.layer_rule({ match = { namespace = "^(bar|apps)$" }, blur = true, ignore_alpha = 0 })

hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind("ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
