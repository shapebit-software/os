-- Moving a workspace along the strip. Workspaces keep their ids, so moving
-- one moves windows and layouts instead: the workspace's windows go to the
-- id it is dropped on, and those in between shift one place toward it.

local workspaces = {}

local function move(window, workspace)
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = "address:" .. window.address, follow = false }))
end

-- Windows wait on these while their workspaces change places.
local parking = 1000

function workspaces.move(from, to)
    if from == to then return end
    -- The ids from `from` to `to`; the first one's windows go to the last,
    -- every other one's to the id before it.
    local ids = {}
    for id = from, to, from < to and 1 or -1 do ids[#ids + 1] = id end
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
        for _, window in ipairs(list) do move(window, parking + i) end
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
