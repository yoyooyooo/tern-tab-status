local status = require("./status")
local POLL_MS = 750
local enabled = tern.kv.get("enabled") ~= false
local pending = nil

local function color_value(value)
    return if value == tern.json.null then nil else value
end

-- Keep one record per tab so reloads and other windows retain the user's color.
local function record_key(tab)
    return "tab:" .. tostring(tab.session) .. ":" .. tostring(tab.id)
end

local function apply_color(cx, tab, desired)
    local key = record_key(tab)
    local saved = tern.kv.get(key)
    local current = color_value(tab.color)
    local dirty = false
    if desired then
        if not saved then
            saved = {original = current or tern.json.null}
            dirty = true
        elseif current ~= color_value(saved.applied) then
            -- A manual color change becomes the color restored after activity.
            saved.original = current or tern.json.null
            dirty = true
        end
        if saved.applied ~= desired then
            saved.applied = desired
            dirty = true
        end
        if dirty then tern.kv.set(key, saved) end
        if current ~= desired then
            cx.layout:color_tab(tab.id, desired)
        end
    elseif saved then
        -- Do not overwrite a manual change made since the last synchronization.
        if current == color_value(saved.applied) then
            cx.layout:color_tab(tab.id, color_value(saved.original))
        end
        tern.kv.set(key, nil)
    end
end

local function is_omp(cx, agent, pane)
    local surface = cx.session:surface(agent.pane, {nodes = 1, depth = 1, max_chars = 128})
    if surface and surface.surface.role == "omp.session" then
        return true
    end
    return pane.program == "omp" or string.match(pane.program or "", "[/\\]omp$") ~= nil
end

local function sync(cx)
    enabled = tern.kv.get("enabled") ~= false
    local by_tab = {}
    if enabled then
        for _, agent in ipairs(cx.agents:list()) do
            local pane = cx.session:pane(agent.pane)
            if pane and is_omp(cx, agent, pane) then
                local result_key = "result:" .. tostring(agent.pane)
                local result = tern.kv.get(result_key)
                if not pane.alert and result ~= nil then
                    tern.kv.set(result_key, nil)
                    result = nil
                end
                if pane.tab then
                    local group = by_tab[pane.tab]
                    if not group then
                        group = {}
                        by_tab[pane.tab] = group
                    end
                    table.insert(group, {
                        state = agent.state,
                        alert = pane.alert,
                        result = if agent.progress and agent.progress.state == "error" then "failed" else result,
                        error = pane.error,
                        exited = pane.exited,
                    })
                end
            end
        end
    end
    for _, tab in ipairs(cx.session:tabs()) do
        apply_color(cx, tab, status.color(by_tab[tab.id] or {}))
    end
end

local tick
local function schedule(ms)
    if pending then pending:cancel() end
    pending = tern.timer(ms, tick)
end

tick = function(cx)
    pending = nil
    if not cx then return end
    sync(cx)
    schedule(POLL_MS)
end

local function refresh()
    schedule(0)
end

tern.on("agent_finished", function(ev, cx)
    local pane = cx.session:pane(ev.pane)
    if tern.kv.get("enabled") == false or not pane or not is_omp(cx, {pane = ev.pane}, pane) then return end
    if ev.result == "done" or ev.result == "failed" then
        tern.kv.set("result:" .. tostring(ev.pane), ev.result)
    end
    -- Let native attention flags settle before sampling; never acknowledge here.
    refresh()
end)

for _, event in ipairs({"focus", "pane_created", "pane_closed", "tab_created", "tab_closed", "command_started", "command_finished", "title"}) do
    tern.on(event, refresh)
end
tern.on("window_start", refresh)

tern.command({
    id = "pause",
    title = "Tern Tab Status: Pause and Restore Tab Colors",
    run = function(cx)
        enabled = false
        tern.kv.set("enabled", false)
        if pending then pending:cancel(); pending = nil end
        sync(cx)
        schedule(POLL_MS)
    end,
})

tern.command({
    id = "resume",
    title = "Tern Tab Status: Resume",
    run = function(cx)
        enabled = true
        tern.kv.set("enabled", true)
        sync(cx)
        schedule(POLL_MS)
    end,
})

-- window_start is not repeated for an already loaded plugin on reload.
schedule(0)
