-- The layouts of ShapeBit Desktop, following the demo. Each workspace has one;
-- the shell changes it with layouts.set and learns it from "layout <workspace>
-- <name>" events. It also learns each workspace's windows in order, and the
-- one Tabs or Accordion shows, from "tiles <workspace> <shown> <windows>"
-- events, with addresses separated by commas; and where the tiles can be
-- resized from "splits <workspace> <splits>" events (splitsOf), which it
-- does with layouts.resize.
--
-- Most layouts are templates: columns of cells, one of them active. Windows
-- fill the cells in the order they opened, the first in the active cell, so a
-- window keeps its place when focus moves. Columns without windows go away,
-- and windows beyond the cells join the last column. Tabs and Accordion show
-- the focused window and hide the others behind it; the shell draws a tab
-- bar above it, or a folded strip beside it for each of the others
-- (WindowTabs.qml).

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

-- The height of Tabs' tab bar, and the width of a window that Accordion
-- folds to the side; the shell draws them as large.
local tabBar = 30
local folded = 34

-- The windows of each workspace in the order they fill its cells, as last
-- placed (layouts.windows).
local order = {}

layouts.names = { "lead", "dwindle", "columns", "center", "grid", "tabs", "rows", "accordion" }
-- The layout of new workspaces, as in the demo; the shell changes it with
-- layouts.setDefault.
layouts.default = "columns"

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

-- Sizes people set by dragging the space between tiles (layouts.resize), per
-- workspace and while its layout stays: { layout, columns = { [i] = width },
-- cells = { ["i k"] = height } }, by the place of the column and the cell
-- among those with windows. They stand in for the template's.
local sizes = {}

-- Where the columns and the cells of each workspace were last placed, for
-- resizing: { columns = { { start, length, weight } }, cells = { [i] = ... } }.
local geometry = {}

local function placeTemplate(ctx, template, workspace, layout)
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

    local own = sizes[workspace]
    if own and own.layout ~= layout then own = nil end
    local area = ctx.area
    local widths = {}
    for i, column in ipairs(used) do
        widths[i] = #used == 1 and 1 or own and own.columns[i] or column.width
    end
    local placed = { columns = {}, cells = {} }
    for i, x in ipairs(split(area.x, area.w, widths)) do
        placed.columns[i] = { start = x[1], length = x[2], weight = widths[i] }
        local cells = used[i].cells
        local heights = {}
        for k, cell in ipairs(cells) do
            heights[k] = #cells > 1 and own and own.cells[i .. " " .. k] or cell.height
        end
        placed.cells[i] = {}
        for k, y in ipairs(split(area.y, area.h, heights)) do
            placed.cells[i][k] = { start = y[1], length = y[2], weight = heights[k] }
            cells[k].target:place({ x = x[1], y = y[1], w = x[2], h = y[2] })
        end
    end
    if workspace then geometry[workspace] = placed end
    return placed
end

-- The places between columns and between cells, where the shell lets people
-- resize them: "c,<column>,0,<x>,<y>,<length>" for the line after a column,
-- and "r,<column>,<cell>,<x>,<y>,<length>" for the one under a cell, joined by
-- semicolons.
local function splitsOf(placed, area)
    local splits = {}
    if not placed then return "-" end
    for i, column in ipairs(placed.columns) do
        if i < #placed.columns then
            splits[#splits + 1] = ("c,%d,0,%d,%d,%d"):format(i, math.floor(column.start + column.length + 0.5),
                math.floor(area.y + 0.5), math.floor(area.h + 0.5))
        end
        for k, cell in ipairs(placed.cells[i]) do
            if k < #placed.cells[i] then
                splits[#splits + 1] = ("r,%d,%d,%d,%d,%d"):format(i, k, math.floor(column.start + 0.5),
                    math.floor(cell.start + cell.length + 0.5), math.floor(column.length + 0.5))
            end
        end
    end
    return #splits > 0 and table.concat(splits, ";") or "-"
end

-- A visible window's box: place() takes half the gap off every edge of a
-- box that is not on the area's edge, so this adds it back.
local function boxFor(area, rect)
    local half = hl.get_config("general.gaps_in").top
    local left = rect.x > area.x and half or 0
    local top = rect.y > area.y and half or 0
    local right = rect.x + rect.w < area.x + area.w and half or 0
    local bottom = rect.y + rect.h < area.y + area.h and half or 0
    return { x = rect.x - left, y = rect.y - top, w = rect.w + left + right, h = rect.h + top + bottom }
end

-- Places the shown window in a box, and the others behind it.
local function showOnly(ctx, shown, box)
    for _, target in ipairs(ctx.targets) do
        if target ~= shown then target:place(box) end
    end
    shown:place(box)
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

-- Tabs and Accordion return the target they show.
local special = {
    -- The focused window under the tab bar.
    tabs = function(ctx)
        local area, focused = ctx.area, focusedTarget(ctx)
        showOnly(ctx, focused, boxFor(area, { x = area.x, y = area.y + tabBar, w = area.w, h = area.h - tabBar }))
        return focused
    end,
    -- A column for each window, a gap apart: the focused one takes the space
    -- the others leave when folded.
    accordion = function(ctx)
        local area, focused = ctx.area, focusedTarget(ctx)
        local gap = 2 * hl.get_config("general.gaps_in").top
        local x = area.x
        for _, target in ipairs(ctx.targets) do
            if target == focused then break end
            x = x + folded + gap
        end
        local width = math.max(1, area.w - (folded + gap) * (#ctx.targets - 1))
        showOnly(ctx, focused, boxFor(area, { x = x, y = area.y, w = width, h = area.h }))
        return focused
    end,
}

-- What the shell last learned of each workspace (the "tiles" event).
local announced = {}

local function announceTiles(workspace, shown, windows)
    local addresses = {}
    for i, window in ipairs(windows) do addresses[i] = window.address end
    local tiles = ("%s %s"):format(shown and shown.address or "-", table.concat(addresses, ","))
    if announced[workspace] == tiles then return end
    announced[workspace] = tiles
    hl.dispatch(hl.dsp.event(("tiles %d %s"):format(workspace, tiles)))
end

-- What the shell last learned of where each workspace can be resized (the
-- "splits" event).
local announcedSplits = {}

local function announceSplits(workspace, splits)
    if announcedSplits[workspace] == splits then return end
    announcedSplits[workspace] = splits
    hl.dispatch(hl.dsp.event(("splits %d %s"):format(workspace, splits)))
end

for _, name in ipairs(layouts.names) do
    hl.layout.register(name, {
        recalculate = function(ctx)
            if #ctx.targets == 0 then return end
            local first = ctx.targets[1].window
            local workspace = first and first.workspace and first.workspace.id
            local shown, placed
            if special[name] then
                shown = special[name](ctx)
            else
                local template = templates[name]
                if name == "grid" and #ctx.targets <= 2 then template = gridOfTwo end
                placed = placeTemplate(ctx, template, workspace, name)
            end
            if workspace then
                local windows = {}
                for i, target in ipairs(ctx.targets) do windows[i] = target.window end
                order[workspace] = windows
                announceTiles(workspace, shown and shown.window, windows)
                announceSplits(workspace, splitsOf(placed, ctx.area))
            end
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
    sizes[workspace] = nil
    if rules[workspace] then rules[workspace]:set_enabled(false) end
    rules[workspace] = hl.workspace_rule({ workspace = tostring(workspace), layout = "lua:" .. name })
    current[workspace] = name
    announce(workspace)
end

-- Moves the line after a column ("c", the column's place) or under a cell
-- ("r", the column's and the cell's place) of a workspace to `at`, a position
-- on the screen, by changing the sizes of the two beside it. Neither gets
-- smaller than a third of both, or 120 pixels.
function layouts.resize(workspace, kind, column, cell, at)
    local placed = geometry[workspace]
    local parts = placed and (kind == "c" and placed.columns or placed.cells[column])
    local index = kind == "c" and column or cell
    if not parts or not parts[index + 1] then return end
    local a, b = parts[index], parts[index + 1]
    local length = a.length + b.length
    local least = math.min(120, length / 3)
    local into = math.max(least, math.min(length - least, at - a.start))
    local weight = a.weight + b.weight
    local own = sizes[workspace]
    if not own or own.layout ~= layouts.of(workspace) then
        own = { layout = layouts.of(workspace), columns = {}, cells = {} }
        sizes[workspace] = own
    end
    local first, second = weight * into / length, weight * (length - into) / length
    if kind == "c" then
        own.columns[index], own.columns[index + 1] = first, second
    else
        own.cells[column .. " " .. index], own.cells[column .. " " .. (index + 1)] = first, second
    end
    hl.dispatch(hl.dsp.layout("refresh"))
end

-- Changes the layout of new workspaces. Workspaces with windows keep theirs;
-- empty ones take the new one.
function layouts.setDefault(name)
    if name == layouts.default or not (templates[name] or special[name]) then return end
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 and not current[workspace.id] and workspace.windows > 0 then
            layouts.set(workspace.id, layouts.default)
        end
    end
    layouts.default = name
    hl.config({ general = { layout = "lua:" .. name } })
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 and not current[workspace.id] then announce(workspace.id) end
    end
end

-- Announces the layout and the windows of every workspace, for a shell that
-- just started.
function layouts.report()
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 then
            announce(workspace.id)
            local tiles = announced[workspace.id]
            if tiles then hl.dispatch(hl.dsp.event(("tiles %d %s"):format(workspace.id, tiles))) end
            local splits = announcedSplits[workspace.id]
            if splits then hl.dispatch(hl.dsp.event(("splits %d %s"):format(workspace.id, splits))) end
        end
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
