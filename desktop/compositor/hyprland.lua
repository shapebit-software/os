-- The compositor configuration of ShapeBit Desktop (Hyprland, Lua).
-- The session starts Hyprland with this file (see session/desktop.desktop);
-- people's own settings do not live here.

-- The shell draws the wallpaper, the bar, and every panel. DESKTOP_SHELL
-- points at a source tree during development (see the Makefile).
local shell = os.getenv("DESKTOP_SHELL") or "/usr/share/desktop/shell"

hl.on("hyprland.start", function()
    hl.exec_cmd("qs --path " .. shell)
    -- UWSM runs the session (session/desktop.desktop) and waits for the
    -- compositor to give systemd its environment; then the session's units
    -- start, such as XDG autostart. UWSM sets NOTIFY_SOCKET; make run does
    -- not, since there the systemd user manager is the developer's own.
    if os.getenv("NOTIFY_SOCKET") then
        hl.exec_cmd("uwsm finalize HYPRLAND_INSTANCE_SIGNATURE")
    end
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

-- Windows are tiles with one gap everywhere: straight corners and a hairline
-- border until the shell applies the person's settings (Compositor.qml
-- setDecoration). Blur is only for the shell's glass (the layer rules below);
-- tiles are opaque, so nothing shows through them.
local gap = 10

hl.config({
    general = {
        gaps_in     = gap / 2,
        gaps_out    = gap,
        border_size = 1,
        col         = { active_border = "rgba(0b08127a)", inactive_border = "rgba(0b08127a)" },
        layout      = "lua:" .. layouts.default,
    },

    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = true },
    },

    -- Windows take the keyboard when clicked, not when the pointer passes
    -- over them, as on macOS.
    input = { follow_mouse = 2 },

    misc = {
        -- The session names the desktop ShapeBit (session/desktop.desktop).
        disable_xdg_env_checks  = true,
        -- The shell owns the background.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- The system bar and the panels are glass. Panels cover the screen, and a
-- panel's shadow is not glass: the blur skips what is mostly transparent.
hl.layer_rule({ match = { namespace = "^bar$" }, blur = true, ignore_alpha = 0 })
-- The dock's items are glass too; the blur skips the faint shadows around them.
hl.layer_rule({ match = { namespace = "^dock$" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ match = { namespace = "^(panel|capture|corner)$" }, blur = true, ignore_alpha = 0.5 })
-- The tabs of Tabs and Accordion cover the screen, so only their glass is blurred.
hl.layer_rule({ match = { namespace = "^tabs$" }, blur = true, ignore_alpha = 0.05 })

-- The capture panel leaves at once, so it is not in the capture.
hl.layer_rule({ match = { namespace = "^capture$" }, no_anim = true })

-- Animations are short and ease out, as on macOS: about a fifth of a second
-- (speeds are in tenths of a second).
hl.curve("out", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({ leaf = "global",     enabled = true, speed = 2.5, bezier = "out" })
hl.animation({ leaf = "windows",    enabled = true, speed = 2.5, bezier = "out" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 2,   bezier = "out", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "out", style = "popin 92%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 1.5, bezier = "out" })
hl.animation({ leaf = "layers",     enabled = true, speed = 1.5, bezier = "out", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "out", style = "slide" })

hl.bind("ALT + Q", hl.dsp.window.close())
-- The next keyboard layout (Settings > Language > Keyboards).
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
-- Full screen covers the bar and the strip; the shell shows a button to end
-- it in the top right corner (FullscreenExit.qml).
hl.bind("ALT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- The brightness keys change the built-in display's (shell/Brightness.qml),
-- held down and on the lock screen too; brightnessctl keeps it above
-- fully dark.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl --class=backlight --quiet set 5%+"),
    { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight --quiet set 5%-"),
    { repeating = true, locked = true })
