-- Workspaces, as in the demo: there is no Overview, so they come and go with
-- their windows. The session starts with one; the shell makes another when
-- something is dropped on the strip's "+" (Strip.qml). A workspace without
-- windows goes away once left, and the one on screen is left as soon as it
-- loses its last window, for the one taking its place on the strip.

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

return workspaces
