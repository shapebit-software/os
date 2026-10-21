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

-- The layouts (layouts.lua) and the workspaces (workspaces.lua), next to
-- this file. The shell calls these globals through dispatch requests.
local here = debug.getinfo(1, "S").source:match("^@(.*/)")
layouts = dofile(here .. "layouts.lua")
workspaces = dofile(here .. "workspaces.lua")

-- Windows are plain tiles: straight corners, no border, no shadow, and one
-- gap everywhere. Blur is only for the shell's glass (the layer rules below);
-- tiles are opaque, so nothing shows through them.
local gap = 10

hl.config({
    general = {
        gaps_in     = gap / 2,
        gaps_out    = gap,
        border_size = 0,
        layout      = "lua:" .. layouts.default,
    },

    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = true },
    },

    misc = {
        -- The shell owns the background.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- The bar and the panels are glass. A panel's shadow is not: the blur skips
-- what is mostly transparent.
hl.layer_rule({ match = { namespace = "^(bar|apps)$" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "^(panel|capture)$" }, blur = true, ignore_alpha = 0.5 })

-- The capture panel leaves at once, so it is not in the capture.
hl.layer_rule({ match = { namespace = "^capture$" }, no_anim = true })

hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind("ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
