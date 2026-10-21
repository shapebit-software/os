-- The layouts of ShapeBit Desktop, following the demo. Each workspace has one;
-- the shell changes it with layouts.set and learns it from "layout <workspace>
-- <name>" events.
--
-- Most layouts are templates: columns of cells, one of them active. Windows
-- fill the cells in the order they opened, the first in the active cell, so a
-- window keeps its place when focus moves. Columns without windows go away,
-- and windows beyond the cells join the last column. Tabs and Accordion follow
-- focus instead.

local layouts = {}

-- A template is a list of columns: { width, { { height, active? }, ... } },
-- with widths and heights relative to their neighbours.
local templates = {
    lead      = { { 1.7, { { 1, true } } }, { 1, { { 1 }, { 1 }, { 1 } } } },
    dwindle   = { { 1, { { 1, true } } }, { 1, { { 1 }, { 1 } } } },
    columns   = { { 1, { { 1, true } } }, { 1, { { 1 } } }, { 1, { { 1 } } } },
    center    = { { 0.5, { { 1 } } }, { 2.4, { { 1, true } } }, { 0.5, { { 1 } } } },
    grid      = { { 1, { { 1, true }, { 1 } } }, { 1, { { 1 }, { 1 } } } },
    rows      = { { 1, { { 1 }, { 1, true }, { 1 } } } },
}
-- Two windows in a grid sit side by side, not one above the other.
local gridOfTwo = { { 1, { { 1, true } } }, { 1, { { 1 } } } }

-- The width of a window that Accordion folds to the side.
local folded = 34

-- The windows of each workspace in the order they fill its cells, as last
-- placed (layouts.windows).
local order = {}

layouts.names = { "lead", "dwindle", "columns", "center", "grid", "tabs", "rows", "accordion" }
layouts.default = "lead"

-- Splits a length into parts by weight; returns the offset and size of each.
local function split(start, length, weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local parts, at = {}, start
    for i, w in ipairs(weights) do
        parts[i] = { at, length * w / total }
        at = at + parts[i][2]
    end
    return parts
end

local function placeTemplate(ctx, template)
    -- The cells in order, and again with the active one first: the order in
    -- which windows fill them.
    local slots, ranked = {}, {}
    for c, column in ipairs(template) do
        for _, cell in ipairs(column[2]) do
            local slot = { column = c, height = cell[1] }
            slots[#slots + 1] = slot
            table.insert(ranked, cell[2] and 1 or #ranked + 1, slot)
        end
    end
    for i, target in ipairs(ctx.targets) do
        if ranked[i] then ranked[i].target = target end
    end
    local used = {}
    for c, column in ipairs(template) do
        local cells = {}
        for _, slot in ipairs(slots) do
            if slot.column == c and slot.target then cells[#cells + 1] = slot end
        end
        if #cells > 0 then used[#used + 1] = { width = column[1], cells = cells } end
    end
    for i = #slots + 1, #ctx.targets do
        table.insert(used[#used].cells, { target = ctx.targets[i], height = 1 })
    end

    local area = ctx.area
    local widths = {}
    for i, column in ipairs(used) do widths[i] = #used == 1 and 1 or column.width end
    for i, x in ipairs(split(area.x, area.w, widths)) do
        local cells = used[i].cells
        local heights = {}
        for k, cell in ipairs(cells) do heights[k] = cell.height end
        for k, y in ipairs(split(area.y, area.h, heights)) do
            cells[k].target:place({ x = x[1], y = y[1], w = x[2], h = y[2] })
        end
    end
end

-- The target with the focused window, or the workspace's last focused one.
local function focusedTarget(ctx)
    local last
    for _, target in ipairs(ctx.targets) do
        local window = target.window
        if window and window.active then return target end
        if window and window.workspace and window.workspace.last_window == window then last = target end
    end
    return last or ctx.targets[1]
end

local special = {
    -- One window at a time, the focused one on top of the others.
    tabs = function(ctx)
        local focused = focusedTarget(ctx)
        for _, target in ipairs(ctx.targets) do
            if target ~= focused then target:place(ctx.area) end
        end
        if focused then focused:place(ctx.area) end
    end,
    -- A column for each window; the focused one takes the space the others
    -- leave when folded.
    accordion = function(ctx)
        local focused = focusedTarget(ctx)
        local widths = {}
        for i, target in ipairs(ctx.targets) do
            widths[i] = target == focused and math.max(1, ctx.area.w - folded * (#ctx.targets - 1)) or folded
        end
        for i, x in ipairs(split(ctx.area.x, ctx.area.w, widths)) do
            ctx.targets[i]:place({ x = x[1], y = ctx.area.y, w = x[2], h = ctx.area.h })
        end
    end,
}

for _, name in ipairs(layouts.names) do
    hl.layout.register(name, {
        recalculate = function(ctx)
            if #ctx.targets == 0 then return end
            local first = ctx.targets[1].window
            if first and first.workspace then
                local windows = {}
                for i, target in ipairs(ctx.targets) do windows[i] = target.window end
                order[first.workspace.id] = windows
            end
            if special[name] then return special[name](ctx) end
            local template = templates[name]
            if name == "grid" and #ctx.targets <= 2 then template = gridOfTwo end
            placeTemplate(ctx, template)
        end,
        -- "refresh" only asks for the windows to be placed again.
        layout_msg = function(_, msg) return msg == "refresh" end,
    })
end

-- The layout of each workspace the shell changed, and the rule that sets it.
local current, rules = {}, {}

-- The windows of a workspace, those it places in their order first.
function layouts.windows(workspace)
    local windows, seen = {}, {}
    for _, window in ipairs(order[workspace] or {}) do
        if window.workspace and window.workspace.id == workspace then
            windows[#windows + 1] = window
            seen[window.address] = true
        end
    end
    for _, window in ipairs(hl.get_workspace_windows(workspace)) do
        if not seen[window.address] then windows[#windows + 1] = window end
    end
    return windows
end

function layouts.of(workspace)
    return current[workspace] or layouts.default
end

local function announce(workspace)
    hl.dispatch(hl.dsp.event(("layout %d %s"):format(workspace, layouts.of(workspace))))
end

function layouts.set(workspace, name)
    if not templates[name] and not special[name] then return end
    if rules[workspace] then rules[workspace]:set_enabled(false) end
    rules[workspace] = hl.workspace_rule({ workspace = tostring(workspace), layout = "lua:" .. name })
    current[workspace] = name
    announce(workspace)
end

-- Announces the layout of every workspace, for a shell that just started.
function layouts.report()
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 then announce(workspace.id) end
    end
end

-- Tabs and Accordion follow focus, which does not place windows again by itself.
hl.on("window.active", function()
    local workspace = hl.get_active_workspace()
    if workspace and (layouts.of(workspace.id) == "tabs" or layouts.of(workspace.id) == "accordion") then
        hl.dispatch(hl.dsp.layout("refresh"))
    end
end)

return layouts
