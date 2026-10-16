local POLL_MS = 750
local pending = nil
local previous_css = nil
local shells = {sh = true, bash = true, zsh = true, fish = true, dash = true, ksh = true, csh = true, tcsh = true}
local function optional(value)
    return if value == tern.json.null then nil else value
end
local function supported(cx, pane, exact)
    local program = optional(pane.program)
    local name = program and string.match(program, "([^/\\]+)$")
    if name == "omp" or name == "pi" then return true end
    if not shells[name] then return false end
    local tree = optional(cx.session:surface(exact, {nodes = 1, depth = 1, max_chars = 128}))
    local surface = tree and optional(tree.surface)
    return surface ~= nil and surface.role == "omp.session"
end
local BASE = [[
:is(#sidebar,#tabbar) .tn-dk {position:static;display:flex;align-items:center;gap:2px;width:auto;height:16px;z-index:1;}
:is(#sidebar,#tabbar) .tn-dk-c {position:static;display:grid;width:13px;height:13px;transform:none;filter:none;animation:none;z-index:auto;}
:is(#sidebar,#tabbar) .tn-dk-c .tn-dk-g {position:static;width:100%;height:100%;}
#sidebar .nav-row {padding-right:24px;}
#tabbar .tt {padding-right:24px;}
:is(#sidebar,#tabbar) .tn-tc {position:absolute;right:10px;top:50%;margin-top:-3.5px;z-index:0;}
#tabbar .tt .fc {display:none;}
:is(#sidebar,#tabbar) .tn-dk-c[data-st]::after {display:none;right:10px;top:50%;bottom:auto;margin-top:-3.5px;width:7px;height:7px;animation:none;opacity:1;}
]]
local function restore_legacy_colors(cx)
    for _, tab in ipairs(cx.session:tabs()) do
        local key = "tab:" .. tostring(tab.session) .. ":" .. tostring(tab.id)
        local saved = tern.kv.get(key)
        if saved then
            local original = optional(saved.original)
            if optional(tab.color) == optional(saved.applied) then
                cx.layout:color_tab(tab.id, original)
                for _, current in ipairs(cx.session:tabs()) do
                    if current.id == tab.id and optional(current.color) == original then
                        tern.kv.set(key, nil)
                        break
                    end
                end
            else
                tern.kv.set(key, nil)
            end
        end
    end
end
local function sync(cx)
    restore_legacy_colors(cx)
    local rules = {}
    if tern.kv.get("enabled") ~= false then
        table.insert(rules, BASE)
        for _, exact in ipairs(tern.kv.get("native-panes") or {}) do
            local pane = cx.session:pane(exact)
            if pane and supported(cx, pane, exact) then
                local read_key = "read:" .. tostring(pane.pane)
                local read = tern.kv.get(read_key)
                if pane.focused and pane.alert and not read then
                    read = true
                    tern.kv.set(read_key, true)
                end
                local selector = ':is(#sidebar,#tabbar) .tn-dk-c[data-pane="' .. exact .. '"]'
                table.insert(rules, selector .. "[data-st='working']::after{display:block;background:#4c9eff;z-index:1;}")
                table.insert(rules, selector .. "[data-st='waiting']::after{display:block;background:#e3c04b;z-index:3;}")
                if not read then
                    table.insert(rules, selector .. "[data-st='done']::after," .. selector .. "[data-st='bell']::after{display:block;background:#4cbb70;z-index:2;}")
                    table.insert(rules, selector .. "[data-st='failed']::after{display:block;background:#ef6b73;z-index:4;}")
                end
            end
        end
    end
    local css = table.concat(rules, "\n")
    if css ~= previous_css then
        tern.css("status", css)
        previous_css = css
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
local function refresh(_, cx)
    sync(cx)
    schedule(POLL_MS)
end
tern.on("agent_finished", function(ev, cx)
    tern.kv.set("read:" .. tostring(ev.pane), if cx.session:focused() == ev.pane then true else nil)
    sync(cx)
    schedule(POLL_MS)
end)
tern.on("focus", function(_, cx)
    local pane = cx.session:focused()
    if pane then tern.kv.set("read:" .. tostring(pane), true) end
    sync(cx)
    schedule(POLL_MS)
end)
tern.on("pane_closed", function(ev, cx)
    tern.kv.set("read:" .. tostring(ev.pane), nil)
    refresh(ev, cx)
end)
tern.on("window_start", function(cx) refresh(nil, cx) end)
for _, event in ipairs({"pane_created", "tab_created", "tab_closed", "command_started", "command_finished", "title", "cwd"}) do
    tern.on(event, refresh)
end
local function new_agent_tab(cx, command)
    local original = cx.settings:get("agent_command")
    local placement = cx.settings:get("agent_placement")
    cx.settings:set_many({agent_command = command, agent_placement = "new_tab"})
    local ok, err = pcall(function() cx.actions:run("new_agent_block") end)
    cx.settings:set_many({agent_command = original, agent_placement = placement})
    if not ok then error(err) end
end
tern.command({id = "new_omp_tab", title = "New OMP Tab", group = "Agents", run = function(cx) new_agent_tab(cx, "omp") end})
tern.command({id = "new_pi_tab", title = "New Pi Tab", group = "Agents", run = function(cx) new_agent_tab(cx, "pi") end})
tern.command({id = "pause", title = "Tern Tab Status: Pause and Restore Tab Colors", run = function(cx)
    tern.kv.set("enabled", false)
    sync(cx)
    schedule(POLL_MS)
end})
tern.command({id = "resume", title = "Tern Tab Status: Resume", run = function(cx)
    tern.kv.set("enabled", true)
    sync(cx)
    schedule(POLL_MS)
end})
schedule(0)
