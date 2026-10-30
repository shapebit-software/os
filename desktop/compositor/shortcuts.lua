-- The keyboard shortcuts. Super moves focus, with Shift the window too; the
-- arrows go to the tile beside, and past the last one to the screen beside;
-- with Alt to the workspace before or after, and the numbers to a workspace
-- by its place on the strip. Each has a description, which the shell's list
-- of shortcuts shows (Super+/, shell/ShortcutsWindow.qml). Keys that type
-- other characters in other keyboard layouts, such as the numbers, are bound
-- by their place (code:). What the shell does, it learns from "shortcut
-- <name>" events (shell/Shortcuts.qml), and the shortcuts themselves from
-- shortcuts.report.

local shortcuts = {}

local function shell(name)
    return hl.dsp.event("shortcut " .. name)
end

-- Every shortcut, as "<keys>|<description>", for the shell's list.
local list = {}

local function bind(keys, description, action, options)
    local all = { description = description }
    for key, value in pairs(options or {}) do all[key] = value end
    hl.bind(keys, action, all)
    list[#list + 1] = keys .. "|" .. description
end

-- Tells the shell every shortcut, in a "shortcuts <keys>|<description>;..."
-- event; the compositor does not tell which key a code: shortcut is on.
function shortcuts.report()
    hl.dispatch(hl.dsp.event("shortcuts " .. table.concat(list, ";")))
end

-- Super alone, pressed and let go with no other key between, opens Apps;
-- Alt let go ends the window switcher, if one of its shortcuts opened it.
list[#list + 1] = "Super_L|Apps"
local down, tapping, switching = {}, false, false
local supers = { [133] = true, [134] = true }
local alts = { [64] = true, [108] = true }

hl.on("input.keyboard.key", function(code, _, state)
    if state == 1 then
        tapping = supers[code] and next(down) == nil
        down[code] = true
        return
    end
    down[code] = nil
    if supers[code] and tapping then hl.dispatch(shell("apps")) end
    if alts[code] and switching then
        switching = false
        hl.dispatch(shell("switch-done"))
    end
    tapping = false
end)

local function switch(name)
    return function()
        switching = true
        hl.dispatch(shell(name))
    end
end

-- Directions --------------------------------------------------------------

local function boxOfWindow(window)
    return { x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y }
end

local function boxOfMonitor(monitor)
    return { x = monitor.x, y = monitor.y, w = monitor.width / monitor.scale, h = monitor.height / monitor.scale }
end

-- The place in `boxes` of the one nearest `from` in a direction, overlapping
-- it across that direction; of those as near, the first.
local function nearest(from, boxes, direction)
    local best, bestGap
    for i, box in ipairs(boxes) do
        local gap, overlap
        if direction == "left" or direction == "right" then
            gap = direction == "right" and box.x - (from.x + from.w) or from.x - (box.x + box.w)
            overlap = math.min(from.y + from.h, box.y + box.h) - math.max(from.y, box.y)
        else
            gap = direction == "down" and box.y - (from.y + from.h) or from.y - (box.y + box.h)
            overlap = math.min(from.x + from.w, box.x + box.w) - math.max(from.x, box.x)
        end
        if gap > -2 and overlap > 0 and (not bestGap or gap < bestGap - 1) then best, bestGap = i, gap end
    end
    return best
end

-- The screen beside the focused one in a direction.
local function monitorBeside(direction)
    local active = hl.get_active_monitor()
    if not active then return nil end
    local others, boxes = {}, {}
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name ~= active.name and not monitor.is_mirror then
            others[#others + 1] = monitor
            boxes[#boxes + 1] = boxOfMonitor(monitor)
        end
    end
    local found = nearest(boxOfMonitor(active), boxes, direction)
    return found and others[found]
end

-- The window beside the focused one in a direction on its workspace. Tabs
-- and Accordion show one window at a time, so left and right go through
-- them in order; a window in full screen has none beside it.
local function windowBeside(window, direction)
    if window.fullscreen ~= 0 then return nil end
    local workspace = window.workspace.id
    local layout = layouts.of(workspace)
    if layout == "tabs" or layout == "accordion" then
        if direction ~= "left" and direction ~= "right" then return nil end
        local windows = layouts.windows(workspace)
        for i, other in ipairs(windows) do
            if other.address == window.address then
                return windows[i + (direction == "left" and -1 or 1)]
            end
        end
        return nil
    end
    -- Most recently focused first, so a window beside several goes back to
    -- the one it came from.
    local others = {}
    for _, other in ipairs(hl.get_workspace_windows(workspace)) do
        if other.address ~= window.address and other.mapped and not other.hidden then others[#others + 1] = other end
    end
    table.sort(others, function(a, b) return a.focus_history_id < b.focus_history_id end)
    local boxes = {}
    for i, other in ipairs(others) do boxes[i] = boxOfWindow(other) end
    local found = nearest(boxOfWindow(window), boxes, direction)
    return found and others[found]
end

function shortcuts.focus(direction)
    local window = hl.get_active_window()
    local other = window and windowBeside(window, direction)
    if other then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. other.address }))
        return
    end
    local monitor = monitorBeside(direction)
    if monitor then hl.dispatch(hl.dsp.focus({ monitor = monitor.name })) end
end

-- The focused window changes places with the one beside it, or past the
-- last, goes to the screen beside, onto the workspace shown there.
function shortcuts.move(direction)
    local window = hl.get_active_window()
    if not window then return end
    local other = windowBeside(window, direction)
    if other then
        hl.dispatch(hl.dsp.window.swap({ window = "address:" .. window.address, target = "address:" .. other.address }))
        return
    end
    local monitor = monitorBeside(direction)
    if monitor then
        hl.dispatch(hl.dsp.window.move({ monitor = monitor.name, window = "address:" .. window.address }))
    end
end

-- Shortcuts ---------------------------------------------------------------

-- Windows.
bind("ALT + Tab", "Next window", switch("switch-next"), { repeating = true })
bind("ALT + SHIFT + Tab", "Previous window", switch("switch-previous"), { repeating = true })
bind("ALT + code:49", "Next window of the app", switch("switch-app-next"), { repeating = true })
bind("ALT + SHIFT + code:49", "Previous window of the app", switch("switch-app-previous"), { repeating = true })
bind("SUPER + Q", "Close window", hl.dsp.window.close())
-- Full screen covers the bars; the shell shows a button to end it in the
-- top right corner (shell/FullscreenExit.qml).
bind("SUPER + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("SUPER + W", "Window menu", shell("window-menu"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind("SUPER + " .. direction, "Focus " .. direction, function() shortcuts.focus(direction) end)
    bind("SUPER + SHIFT + " .. direction, "Move window " .. direction, function() shortcuts.move(direction) end)
end

-- Workspaces.
bind("SUPER + ALT + left", "Previous workspace", function() workspaces.step(-1) end)
bind("SUPER + ALT + right", "Next workspace", function() workspaces.step(1) end)
bind("SUPER + ALT + SHIFT + left", "Move window to previous workspace", function() workspaces.sendStep(-1) end)
bind("SUPER + ALT + SHIFT + right", "Move window to next workspace", function() workspaces.sendStep(1) end)
for place = 1, 8 do
    local key = "code:" .. (9 + place)
    bind("SUPER + " .. key, "Workspace " .. place, function() workspaces.go(place) end)
    bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. place, function() workspaces.send(place) end)
end

-- The shell.
bind("SUPER + N", "Notifications", shell("notifications"))
bind("SUPER + I", "Settings", shell("settings"))
bind("SUPER + L", "Lock", shell("lock"))
bind("CTRL + ALT + Delete", "System menu", shell("system"))
bind("SUPER + code:61", "Keyboard shortcuts", shell("help"))
-- The keyboard layouts in Settings > Language > Keyboards.
bind("SUPER + space", "Next keyboard layout", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
bind("SUPER + SHIFT + space", "Previous keyboard layout", hl.dsp.exec_cmd("hyprctl switchxkblayout all prev"))

-- Capturing (shell/Capture.qml). With Alt, Print is SysRq, so it is bound by
-- its place.
local print = "code:107"
bind(print, "Capture", shell("capture"))
bind("ALT + " .. print, "Capture window", shell("capture-window"))
bind("SUPER + " .. print, "Capture screen", shell("capture-screen"))
bind("SHIFT + " .. print, "Record", shell("capture-record"))

-- The sound and media keys (shell/Audio.qml), and the brightness keys, which
-- change the built-in display's (shell/Brightness.qml), work on the lock
-- screen too; brightnessctl keeps it above fully dark.
local held = { locked = true, repeating = true }
local locked = { locked = true }
bind("XF86AudioRaiseVolume", "Volume up", shell("volume-up"), held)
bind("XF86AudioLowerVolume", "Volume down", shell("volume-down"), held)
bind("XF86AudioMute", "Mute", shell("mute"), locked)
bind("XF86AudioMicMute", "Mute microphone", shell("mute-microphone"), locked)
bind("XF86AudioPlay", "Play or pause", shell("play"), locked)
bind("XF86AudioPause", "Play or pause", shell("play"), locked)
bind("XF86AudioNext", "Next track", shell("next-track"), locked)
bind("XF86AudioPrev", "Previous track", shell("previous-track"), locked)
bind("XF86MonBrightnessUp", "Brightness up",
    hl.dsp.exec_cmd("brightnessctl --class=backlight --quiet set 5%+"), held)
bind("XF86MonBrightnessDown", "Brightness down",
    hl.dsp.exec_cmd("brightnessctl --class=backlight --quiet set 5%-"), held)

return shortcuts
