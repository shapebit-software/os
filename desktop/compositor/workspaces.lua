-- Workspaces, as in the demo: there is no Overview, so they come and go with
-- their windows. The session starts with one; the shell makes another when
-- something is dropped on the strip's "+" (Strip.qml). A workspace without
-- windows goes away once left, and the one on screen is left as soon as it
-- loses its last window, for the one taking its place on the strip. The
-- keyboard goes to them and moves windows there by their place on the strip
-- (shortcuts.lua).

local workspaces = {}

-- The ids of a monitor's workspaces, in order.
local function idsOn(monitor, withWindows)
    local ids = {}
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 and workspace.monitor and workspace.monitor.name == monitor
            and (not withWindows or workspace.windows > 0) then
            ids[#ids + 1] = workspace.id
        end
    end
    table.sort(ids)
    return ids
end

local function leaveEmpty()
    local active = hl.get_active_workspace()
    if not active or active.id < 1 or active.windows > 0 or not active.monitor then return end
    local ids = idsOn(active.monitor.name, true)
    if #ids == 0 then return end
    local next = ids[#ids]
    for _, id in ipairs(ids) do
        if id > active.id then
            next = id
            break
        end
    end
    hl.dispatch(hl.dsp.focus({ workspace = next }))
end

-- Checked a moment after a window goes, once the compositor is done moving
-- it: going to another workspace in the middle of that has no effect, and
-- workspaces.move empties workspaces only on the way.
local check
local function soon()
    check = hl.timer(leaveEmpty, { timeout = 50, type = "oneshot" })
end
hl.on("window.destroy", soon)
hl.on("window.move_to_workspace", soon)

local function move(window, workspace)
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = "address:" .. window.address, follow = false }))
end

-- Moves a workspace to the place of another on the strip. Workspaces are
-- in the order of their ids, so this moves windows and layouts instead: the
-- workspace's go to the other's id, and those in between shift one place
-- toward where it was.
function workspaces.move(from, to)
    local workspace = hl.get_workspace(from)
    if from == to or not workspace or not workspace.monitor then return end
    local all = idsOn(workspace.monitor.name, false)
    local ids = {}
    for _, id in ipairs(all) do
        if id >= math.min(from, to) and id <= math.max(from, to) then ids[#ids + 1] = id end
    end
    if from > to then
        local reversed = {}
        for i = #ids, 1, -1 do reversed[#reversed + 1] = ids[i] end
        ids = reversed
    end
    -- The first id's windows go to the last, every other one's to the id
    -- before it.
    local windows, names = {}, {}
    for i, id in ipairs(ids) do
        windows[i] = layouts.windows(id)
        names[i] = layouts.of(id)
    end
    local active = hl.get_active_workspace()
    active = active and active.id

    -- Every window waits on a workspace of its own first, so each lands on
    -- an empty one, in its order.
    for i, list in ipairs(windows) do
        for _, window in ipairs(list) do move(window, "name:parking" .. i) end
    end
    for i, list in ipairs(windows) do
        local target = i == 1 and ids[#ids] or ids[i - 1]
        layouts.set(target, names[i])
        for _, window in ipairs(list) do move(window, target) end
        -- The workspace on screen stays on screen.
        if ids[i] == active then hl.dispatch(hl.dsp.focus({ workspace = target })) end
    end
end

-- The most workspaces the strip makes (shell/Workspaces.qml).
local most = 8

-- The focused screen's workspaces with windows, in order, as the strip shows
-- them, and the place of the one on screen among them: half a place before
-- the next one when it has no windows.
local function shown()
    local active = hl.get_active_workspace()
    if not active or not active.monitor then return {}, 0 end
    local ids = idsOn(active.monitor.name, true)
    local at = #ids + 0.5
    for i, id in ipairs(ids) do
        if id >= active.id then
            at = id == active.id and i or i - 0.5
            break
        end
    end
    return ids, at
end

-- The place one before or after the one on screen.
local function beside(at, by)
    return by < 0 and math.ceil(at + by) or math.floor(at + by)
end

-- Goes to the focused screen's workspace at a place, counted from 1. There
-- is none past the last.
function workspaces.go(place)
    local ids = shown()
    if ids[place] then hl.dispatch(hl.dsp.focus({ workspace = ids[place] })) end
end

-- Goes to the workspace before (-1) or after (1) the one on screen.
function workspaces.step(by)
    local _, at = shown()
    workspaces.go(beside(at, by))
end

-- Moves the focused window to the workspace at a place, and goes with it.
-- The place after the last makes a new workspace, as the strip's "+" does,
-- up to the most.
function workspaces.send(place)
    local window = hl.get_active_window()
    local ids = shown()
    if not window or place < 1 then return end
    local target = ids[place]
    if not target and place == #ids + 1 and #ids < most then
        target = 0
        for _, workspace in ipairs(hl.get_workspaces()) do target = math.max(target, workspace.id) end
        target = target + 1
    end
    if target and target ~= window.workspace.id then
        hl.dispatch(hl.dsp.window.move({ workspace = target, window = "address:" .. window.address }))
    end
end

-- Moves the focused window to the workspace before (-1) or after (1) the one
-- on screen; after the last, to a new one.
function workspaces.sendStep(by)
    local _, at = shown()
    workspaces.send(beside(at, by))
end

return workspaces
