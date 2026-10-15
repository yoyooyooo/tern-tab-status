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
            pane = function() error("session:pane is unavailable") end,
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
        local agent = {
            pane = id, tab = tab.id, session = tab.session, program = program or "omp",
            state = state, alert = alert or false, progress = null, error = null, exited = null,
            alive = true, at_prompt = state == "idle", busy = state == "working",
            kind = "agent", floating = false, focused = false, host = 0, parked = false,
        }
        self.panes[id] = agent
        table.insert(self.agents, agent)
        if role then self.surfaces[id] = {surface = {role = role}} end
        return agent, agent
    end
    r:boot()
    return r
end

local function tab_fixture(color, store, session)
    local r = runtime(store)
    local tab = {id = 7, session = session or 4, color = color}
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

test("rich snapshots drive failure and read restore without pane lookup", function()
    local r, tab = tab_fixture("purple")
    tab.id = 55834574858
    local pane = 55834574884
    local agent = r:add(pane, tab, "working", false, "/opt/bin/omp")
    r:tick()
    equal(tab.color, "blue", "Null error and exit do not imply failure")
    agent.state = "idle"
    agent.alert = true
    r:event("agent_finished", {pane = pane, result = "failed"})
    r:tick()
    equal(tab.color, "red", "Snapshot attention and event result")
    r:boot()
    r:tick()
    equal(tab.color, "red", "Failure survives reload")
    agent.alert = null
    r:event("focus")
    r:tick()
    equal(tab.color, "purple", "Read restores original color")
    agent.alert = true
    r:tick()
    equal(tab.color, "green", "Later native attention has no stale failure")
    agent.alert = false
    agent.state = "working"
    agent.progress = {state = "error"}
    r:tick()
    equal(tab.color, "blue", "Acknowledged progress failure remains working")
    agent.alert = true
    r:tick()
    equal(tab.color, "red", "Progress failure requires native attention")
    agent.state = "idle"
    agent.alert = false
    r:tick()
    equal(tab.color, "purple", "Failure read restores original color")
end)

test("snapshot native failures normalize nullable optional fields", function()
    local r, tab = tab_fixture("purple")
    local agent = r:add(1, tab, "idle", true)
    r:tick()
    equal(tab.color, "green", "Null error, progress and exit are absent")
    agent.error = "Provider failed"
    r:tick()
    equal(tab.color, "red", "Snapshot error")
    agent.error = null
    agent.exited = 1
    r:tick()
    equal(tab.color, "red", "Snapshot failed exit")
    agent.exited = 0
    r:tick()
    equal(tab.color, "green", "Snapshot successful exit")
    agent.alert = null
    r:tick()
    equal(tab.color, "purple", "Null attention is absent")
end)

test("missing and unsupported panes cannot retain completion failures", function()
    for _, change in ipairs({"missing", "unsupported"}) do
        local r, tab = tab_fixture("purple")
        local agent = r:add(1, tab, "idle", true)
        r:event("agent_finished", {pane = 1, result = "failed"})
        r:tick()
        equal(tab.color, "red", "Initial failure")
        if change == "missing" then
            r.agents = {}
            r:event("pane_closed", {pane = 1})
        else
            agent.program = "unknown"
        end
        r:tick()
        equal(tab.color, "purple", "Ineligible snapshot restores color")
        agent.program = "omp"
        r.agents = {agent}
        r:tick()
        equal(tab.color, "green", "Stale failure was pruned")
    end
end)

test("finished events defer eligibility to the next snapshot", function()
    local r, tab = tab_fixture("purple")
    r:event("agent_finished", {pane = 1, result = "failed"})
    r:add(1, tab, "idle", true)
    r:tick()
    equal(tab.color, "red", "Completion can precede snapshot publication")
    r:event("agent_finished", {pane = 1, result = "done"})
    r:tick()
    equal(tab.color, "green", "Latest completion replaces failure")
end)

test("one window cannot discard another window's failure result", function()
    local store = {}
    local first, a = tab_fixture("purple", store, 4)
    local second, b = tab_fixture("orange", store, 5)
    first:add(1, a, "idle", true)
    second:add(2, b, "idle", true)
    first:event("agent_finished", {pane = 1, result = "failed"})
    second:event("agent_finished", {pane = 2, result = "failed"})
    first:tick()
    second:tick()
    equal(a.color, "red", "First window retains failure")
    equal(b.color, "red", "Second window retains failure")
    first.agents = {}
    first:event("pane_closed", {pane = 1})
    first:tick()
    second:tick()
    equal(a.color, "purple", "Closed pane restores first window")
    equal(b.color, "red", "Other window's result survives cleanup")
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

test("pi failures and OMP activity share the same attention rules", function()
    local r, tab = tab_fixture("purple")
    local piPane, piAgent = r:add(1, tab, "working", false, "/opt/bin/pi")
    r:add(2, tab, "working")
    r:tick()
    equal(tab.color, "blue", "Both agents working")
    piAgent.state = "waiting_input"
    r:tick()
    equal(tab.color, "yellow", "Pi input takes priority")
    piAgent.state = "idle"
    piPane.alert = true
    r:event("agent_finished", {pane = 1, result = "failed"})
    r:tick()
    equal(tab.color, "red", "Pi failure result retained")
    piPane.alert = false
    r:event("focus")
    r:tick()
    equal(tab.color, "blue", "Viewed Pi leaves OMP working")
end)

test("agent tabs preserve existing panes and launch preferences", function()
    for _, program in ipairs({"pi", "omp"}) do
        for _, placement in ipairs({"split", "replace_if_alone", "new_tab"}) do
            local r, original = tab_fixture("purple")
            local preferences = {agent_command = "omp --model custom", agent_placement = placement}
            local focused = 1
            local originalPane = r:add(1, original, "idle")
            r.cx.session.focused = function() return focused end
            r.cx.settings = {
                get = function(_, key) return preferences[key] end,
                set = function(_, key, value) preferences[key] = value end,
                set_many = function(_, patch)
                    for key, value in pairs(patch) do preferences[key] = value end
                end,
            }
            r.cx.actions = {run = function()
                if preferences.agent_placement == "replace_if_alone" then
                    r.panes[1] = nil
                end
                local destination = original
                if preferences.agent_placement == "new_tab" then
                    destination = {id = 8, session = original.session}
                    table.insert(r.tabs, destination)
                end
                r:add(2, destination, "idle", false, preferences.agent_command)
                focused = 2
            end}
            r.cx.layout.move_to_new_tab = function() return nil, "unknown block/session" end
            r:command(if program == "pi" then "new_pi_tab" else "new_omp_tab")
            equal(r.panes[1], originalPane, "Existing conversation preserved")
            equal(r.panes[1].tab, original.id, "Existing pane stays in its tab")
            equal(r.panes[2].tab, 8, "New conversation has its own tab")
            equal(r.panes[2].program, program, "Chosen agent")
            equal(focused, 2, "New conversation receives focus")
            equal(preferences.agent_command, "omp --model custom", "Custom default restored")
            equal(preferences.agent_placement, placement, "Placement restored")
        end
    end
end)

test("failed agent launch restores command and placement", function()
    local r = runtime()
    local preferences = {agent_command = "omp --model custom", agent_placement = "replace_if_alone"}
    r.cx.settings = {
        get = function(_, key) return preferences[key] end,
        set_many = function(_, patch)
            for key, value in pairs(patch) do preferences[key] = value end
        end,
    }
    r.cx.actions = {run = function() error("Launch refused") end}
    local ok = pcall(function() r:command("new_pi_tab") end)
    equal(ok, false, "Launch failure reported")
    equal(preferences.agent_command, "omp --model custom", "Custom default preserved on failure")
    equal(preferences.agent_placement, "replace_if_alone", "Placement preserved on failure")
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

test("unknown programs and near matches are unsupported", function()
    for _, program in ipairs({"unknown", "myomp", "/opt/bin/omp-helper", "pi.exe", "", null}) do
        local r, tab = tab_fixture("purple")
        r:add(1, tab, "working", true, program, "omp.session")
        r:event("agent_finished", {pane = 1, result = "failed"})
        r:tick()
        equal(tab.color, "purple", "Unknown program ignored even with a surface")
    end
end)

test("shell surfaces are sampled again when support changes", function()
    local r, tab = tab_fixture("purple")
    r:add(1, tab, "working", false, "/bin/zsh", "omp.session")
    r:tick()
    equal(tab.color, "blue", "OMP shell surface")
    r.surfaces[1] = {surface = null}
    r:tick()
    equal(tab.color, "purple", "Null surface removes support")
    r.surfaces[1] = null
    r:tick()
    equal(tab.color, "purple", "Null response remains unsupported")
    r.surfaces[1] = {surface = {role = "omp.session"}}
    r:tick()
    equal(tab.color, "blue", "Reappearing surface restores support")
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
    r:event("pane_closed", {pane = 1})
    r:tick()
    equal(tab.color, "purple", "Agent removed")
end)

return cases
