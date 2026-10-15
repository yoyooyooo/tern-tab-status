local cases = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function test(label, run)
    local ok, err = pcall(run)
    assert(ok, label .. ": " .. tostring(err))
    cases += 1
end

local null = {}
local function clone(value)
    if type(value) ~= "table" or value == null then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = clone(item) end
    return out
end

local function runtime(store)
    local r = {agents = {}, panes = {}, tabs = {}, surfaces = {}, store = store or {}, writes = 0}
    r.cx = {
        agents = {list = function() return r.agents end},
        session = {
            pane = function(_, id) return r.panes[id] end,
            tabs = function() return r.tabs end,
            surface = function(_, id) return r.surfaces[id] end,
        },
        layout = {color_tab = function(_, id, color)
            for _, tab in ipairs(r.tabs) do
                if tab.id == id then
                    tab.color = color
                    r.writes += 1
                    return
                end
            end
            error("Unknown tab " .. tostring(id))
        end},
    }
    function r:boot()
        self.handlers = {}
        self.commands = {}
        self.timer = nil
        local api = {
            json = {null = null},
            kv = {
                get = function(key) return clone(self.store[key]) end,
                set = function(key, value) self.store[key] = clone(value) end,
            },
            on = function(event, fn) self.handlers[event] = fn end,
            command = function(spec) self.commands[spec.id] = spec.run end,
            timer = function(ms, fn)
                local timer = {ms = ms, fn = fn, canceled = false}
                function timer:cancel() self.canceled = true end
                self.timer = timer
                return timer
            end,
        }
        load_plugin(api)
    end
    function r:tick()
        local timer = self.timer
        assert(timer and not timer.canceled, "Expected a scheduled refresh")
        self.timer = nil
        timer.fn(self.cx)
    end
    function r:event(name, event)
        self.handlers[name](event or {}, self.cx)
    end
    function r:command(name)
        self.commands[name](self.cx)
    end
    function r:add(id, tab, state, alert, program, role)
        local pane = {tab = tab.id, alert = alert or false, program = program or "omp"}
        local agent = {pane = id, state = state}
        self.panes[id] = pane
        table.insert(self.agents, agent)
        if role then self.surfaces[id] = {surface = {role = role}} end
        return pane, agent
    end
    r:boot()
    return r
end

local function tab_fixture(color, store, session)
    local r = runtime(store)
    local tab = {id = 7, session = session or "session", color = color}
    table.insert(r.tabs, tab)
    return r, tab
end

test("failure requires native attention", function()
    equal(status.color({{state = "idle", result = "failed", alert = false}}), nil, "Viewed failure")
    equal(status.color({{state = "working", error = "error", alert = false}}), "blue", "Active error without attention")
    equal(status.color({{state = "idle", alert = true, exited = 1}}), "red", "Nonzero exit")
    equal(status.color({{state = "idle", alert = true, exited = 0}}), "green", "Successful exit attention")
    equal(status.color({{state = "idle", alert = true, error = "error"}}), "red", "Pane error")
end)

test("aggregation priority is independent of pane order", function()
    local states = {
        {state = "idle"},
        {state = "working"},
        {state = "idle", alert = true},
        {state = "waiting_input"},
        {state = "idle", alert = true, result = "failed"},
    }
    local colors = {nil, "blue", "green", "yellow", "red"}
    for left = 1, 5 do
        for right = 1, 5 do
            equal(status.color({states[left], states[right]}), colors[math.max(left, right)], "Priority")
        end
    end
    equal(status.color({}), nil, "Empty tab")
end)

test("acknowledging one pane retains the other pane's work", function()
    local r, tab = tab_fixture(nil)
    local finished = r:add(1, tab, "idle", true)
    r:add(2, tab, "working")
    r:tick()
    equal(tab.color, "green", "Pending completion")
    finished.alert = false
    r:event("focus")
    r:tick()
    equal(tab.color, "blue", "Other pane still working")
end)

test("input waits survive focus until the agent state changes", function()
    local r, tab = tab_fixture(nil)
    local pane, agent = r:add(1, tab, "waiting_input", true)
    r:tick()
    equal(tab.color, "yellow", "Waiting")
    pane.alert = false
    r:event("focus")
    r:tick()
    equal(tab.color, "yellow", "Viewed input wait")
    agent.state = "idle"
    r:tick()
    equal(tab.color, nil, "Wait resolved")
end)

test("completion results clear with native attention", function()
    local r, tab = tab_fixture(nil)
    local pane = r:add(1, tab, "idle", true)
    r:event("agent_finished", {pane = 1, result = "failed"})
    r:tick()
    equal(tab.color, "red", "Failed completion")
    pane.alert = false
    r:event("focus")
    r:tick()
    equal(tab.color, nil, "Viewed failure")
    pane.alert = true
    r:event("agent_finished", {pane = 1, result = "done"})
    r:tick()
    equal(tab.color, "green", "Later successful completion")
end)

test("progress errors use red only while attention remains", function()
    local r, tab = tab_fixture(nil)
    local pane, agent = r:add(1, tab, "working", true)
    agent.progress = {state = "error"}
    r:tick()
    equal(tab.color, "red", "Progress error with attention")
    pane.alert = false
    r:tick()
    equal(tab.color, "blue", "Progress error acknowledged")
end)

test("native attention is never acknowledged by synchronization", function()
    local r, tab = tab_fixture(nil)
    local pane = r:add(1, tab, "idle", true)
    r:tick()
    r:command("pause")
    r:command("resume")
    equal(pane.alert, true, "Native attention")
    equal(tab.color, "green", "Attention still visible")
end)

test("ordinary shells keep their colors while OMP surfaces are recognized", function()
    local r, tab = tab_fixture("purple")
    r:add(1, tab, "working", false, "zsh")
    r:tick()
    equal(tab.color, "purple", "Shell ignored")
    r.surfaces[1] = {surface = {role = "omp.session"}}
    r:tick()
    equal(tab.color, "blue", "OMP surface recognized")
    r:command("pause")
    equal(tab.color, "purple", "Original shell tab color restored")
end)

test("OMP executable paths are recognized", function()
    for _, program in ipairs({"/opt/bin/omp", "C:\\tools\\omp"}) do
        local r, tab = tab_fixture(nil)
        r:add(1, tab, "working", false, program)
        r:tick()
        equal(tab.color, "blue", "Executable path")
    end
end)

test("manual colors observed during activity become the restore color", function()
    local r, tab = tab_fixture("purple")
    r:add(1, tab, "working")
    r:tick()
    tab.color = "orange"
    r:tick()
    equal(tab.color, "blue", "Status reapplied")
    r:command("pause")
    equal(tab.color, "orange", "Manual color restored")
    r:command("resume")
    equal(tab.color, "blue", "Status resumed")
end)

test("manual colors made just before becoming idle are preserved", function()
    local r, tab = tab_fixture(nil)
    local _, agent = r:add(1, tab, "working")
    r:tick()
    tab.color = "orange"
    agent.state = "idle"
    r:tick()
    equal(tab.color, "orange", "Manual color not overwritten")
end)

test("reload retains original colors and pause preference", function()
    local r, tab = tab_fixture("purple")
    r:add(1, tab, "working")
    r:tick()
    r:boot()
    r:tick()
    r:command("pause")
    equal(tab.color, "purple", "Original survives reload")
    r:boot()
    r:tick()
    equal(tab.color, "purple", "Pause survives reload")
    r:command("resume")
    equal(tab.color, "blue", "Resume after reload")
end)

test("shared pause restores each window's own original color", function()
    local store = {}
    local first, a = tab_fixture("purple", store, "first")
    local second, b = tab_fixture("orange", store, "second")
    first:add(1, a, "working")
    second:add(2, b, "working")
    first:tick()
    second:tick()
    first:command("pause")
    second:tick()
    equal(a.color, "purple", "First window")
    equal(b.color, "orange", "Second window")
end)

test("losing an OMP agent restores the tab without clearing other tabs", function()
    local r, tab = tab_fixture("purple")
    r:add(1, tab, "working")
    r:tick()
    r.agents = {}
    r:event("pane_closed")
    r:tick()
    equal(tab.color, "purple", "Agent removed")
end)

return cases
