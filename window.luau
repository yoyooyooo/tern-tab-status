local status = require("./status")
local POLL_MS = 750
local enabled = tern.kv.get("enabled") ~= false
local pending = nil

local function optional_value(value)
    return if value == tern.json.null then nil else value
end

-- Keep one record per tab so reloads and other windows retain the user's color.
local function record_key(tab)
    return "tab:" .. tostring(tab.session) .. ":" .. tostring(tab.id)
end

local function apply_color(cx, tab, desired)
    local key = record_key(tab)
    local saved = tern.kv.get(key)
    local current = optional_value(tab.color)
    local dirty = false
    if desired then
        if not saved then
            saved = {original = current or tern.json.null}
            dirty = true
        elseif current ~= optional_value(saved.applied) then
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
        if current == optional_value(saved.applied) then
            cx.layout:color_tab(tab.id, optional_value(saved.original))
        end
        tern.kv.set(key, nil)
    end
end

local shells = {sh = true, bash = true, zsh = true, fish = true, dash = true, ksh = true, csh = true, tcsh = true}

local function is_supported(cx, agent)
    local program = optional_value(agent.program)
    local basename = program and string.match(program, "([^/\\]+)$")
    if basename == "omp" or basename == "pi" then return true end
    if not shells[basename] then return false end
    local surface = optional_value(cx.session:surface(agent.pane, {nodes = 1, depth = 1, max_chars = 128}))
    local root = surface and optional_value(surface.surface)
    return root ~= nil and root.role == "omp.session"
end

local function sync(cx)
    enabled = tern.kv.get("enabled") ~= false
    local by_tab = {}
    for _, agent in ipairs(cx.agents:list()) do
        local key = "result:" .. tostring(agent.pane)
        local result = tern.kv.get(key)
        local alert = optional_value(agent.alert)
        local supported = is_supported(cx, agent)
        if result ~= nil and (not supported or not alert) then
            tern.kv.set(key, nil)
            result = nil
        end
        if supported then
            local tab = optional_value(agent.tab)
            if enabled and tab ~= nil then
                local group = by_tab[tab]
                if not group then
                    group = {}
                    by_tab[tab] = group
                end
                local progress = optional_value(agent.progress)
                table.insert(group, {
                    state = optional_value(agent.state),
                    alert = alert,
                    result = if progress and progress.state == "error" then "failed" else result,
                    error = optional_value(agent.error),
                    exited = optional_value(agent.exited),
                })
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

tern.on("agent_finished", function(ev)
    if ev.result == "done" or ev.result == "failed" then
        tern.kv.set("result:" .. tostring(ev.pane), ev.result)
    end
    -- Let native attention flags settle before sampling; never acknowledge here.
    refresh()
end)

tern.on("pane_closed", function(ev)
    tern.kv.set("result:" .. tostring(ev.pane), nil)
    refresh()
end)

for _, event in ipairs({"focus", "pane_created", "tab_created", "tab_closed", "command_started", "command_finished", "title"}) do
    tern.on(event, refresh)
end
tern.on("window_start", refresh)

local function new_agent_tab(cx, command)
    local original = cx.settings:get("agent_command")
    local placement = cx.settings:get("agent_placement")
    -- Tern 0.8.3 captures both preferences synchronously during creation.
    -- Create the Agent Block in its tab directly, then restore both preferences.
    cx.settings:set_many({agent_command = command, agent_placement = "new_tab"})
    local ok, err = pcall(function() cx.actions:run("new_agent_block") end)
    cx.settings:set_many({agent_command = original, agent_placement = placement})
    if not ok then error(err) end
end

tern.command({
    id = "new_omp_tab",
    title = "New OMP Tab",
    group = "Agents",
    run = function(cx) new_agent_tab(cx, "omp") end,
})

tern.command({
    id = "new_pi_tab",
    title = "New Pi Tab",
    group = "Agents",
    run = function(cx) new_agent_tab(cx, "pi") end,
})

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
