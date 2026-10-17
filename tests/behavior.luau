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
    local copy = {}
    for key, item in pairs(value) do copy[key] = clone(item) end
    return copy
end

local function environment(store)
    local e = {store = store or {}, native = {}, handlers = {}}
    local function get(key) return clone(e.store[key]) end
    local function set(key, value)
        e.store[key] = clone(value)
    end
    e.kv = {get = get, set = set}
    load_host_plugin({
        kv = e.kv,
        pane = {list = function() return clone(e.native) end},
        on = function(name, fn) e.handlers[name] = fn end,
        timer = function(ms, fn)
            e.host_timer = {ms = ms, fn = fn}
            return {cancel = function() end}
        end,
    })
    function e:tick_host()
        local timer = self.host_timer
        assert(timer, "Host refresh scheduled")
        self.host_timer = nil
        timer.fn()
    end
    return e
end

local function runtime(e)
    e = e or environment()
    local r = {
        env = e, store = e.store, panes = {}, tabs = {}, surfaces = {}, focused = nil,
        pane_reads = 0, surface_reads = 0, color_writes = 0, css_calls = 0,
    }
    r.cx = {
        agents = {list = function() error("Agent snapshots must not be read") end},
        session = {
            pane = function(_, exact)
                assert(type(exact) == "string", "Native pane lookup keeps the exact string ID")
                r.pane_reads += 1
                return r.panes[exact]
            end,
            focused = function() return r.focused end,
            tabs = function() return clone(r.tabs) end,
            surface = function(_, exact, options)
                r.surface_reads += 1
                equal(options.nodes, 1, "Surface node budget")
                equal(options.depth, 1, "Surface depth budget")
                equal(options.max_chars, 128, "Surface text budget")
                return r.surfaces[exact]
            end,
        },
        layout = {color_tab = function(_, id, color)
            r.color_writes += 1
            if r.unaddressable == id then return end
            for _, tab in ipairs(r.tabs) do
                if tab.id == id then tab.color = color; return end
            end
            error("Unknown tab " .. tostring(id))
        end},
    }
    function r:boot()
        if self.timer then self.timer:cancel() end
        self.handlers, self.commands = {}, {}
        local api = {
            json = {null = null, decode = function(value) return value end}, kv = e.kv,
            css = function(_, css)
                self.css = css
                self.css_calls += 1
            end,
            on = function(event, fn) self.handlers[event] = fn end,
            command = function(spec) self.commands[spec.id] = spec.run end,
            timer = function(ms, fn)
                local timer = {ms = ms, fn = fn, canceled = false}
                function timer:cancel() self.canceled = true end
                self.timer = timer
                return timer
            end,
        }
        api.process = {run = function(_, _, callback)
            self.inspect_callback = callback
        end}
        load_window_plugin(api)
    end
    function r:tick()
        local timer = self.timer
        assert(timer and not timer.canceled, "Window refresh scheduled")
        self.timer = nil
        timer.fn(self.cx)
    end
    function r:event(name, event) self.handlers[name](event or {}, self.cx) end
    function r:command(name) self.commands[name](self.cx) end
    function r:add(id, program, event_id)
        local exact = string.format("%.0f", id)
        local pane = {pane = event_id or id, program = program or "omp", focused = false, alert = false}
        self.panes[exact] = pane
        table.insert(e.native, {pane = id})
        e:tick_host()
        return pane, exact
    end
    function r:focus(pane)
        for _, item in pairs(self.panes) do item.focused = item == pane end
        self.focused = pane and pane.pane or nil
    end
    r:boot()
    return r
end
local function read(r, pane) return r.store["read:" .. tostring(pane.pane)] end
local function tab_fixture(color, store)
    local r = runtime(environment(store))
    local tab = {id = 7, session = 4, color = color}
    table.insert(r.tabs, tab)
    return r, tab
end

test("host publishes exact native pane IDs and refreshes the roster", function()
    local e = environment()
    e.native = {{pane = 360382115872779}, {pane = 360382115872777}}
    e:tick_host()
    local published = {}
    for _, id in ipairs(e.store["native-panes"]) do published[id] = true end
    equal(#e.store["native-panes"], 2, "Initial roster size")
    equal(published["360382115872777"], true, "First complete ID")
    equal(published["360382115872779"], true, "Second complete ID")
    e.native = {{pane = 360382115872779}, {pane = 186951336460348}}
    e:tick_host()
    published = {}
    for _, id in ipairs(e.store["native-panes"]) do published[id] = true end
    equal(#e.store["native-panes"], 2, "Replacement roster size")
    equal(published["186951336460348"], true, "New native pane published")
    equal(published["360382115872777"], nil, "Removed native pane unpublished")
end)

test("lifecycle events discover panes without a timer callback", function()
    local e = environment()
    local r = runtime(e)
    r:tick()
    local exact = "360382115872777"
    e.native = {{pane = 360382115872777}}
    r.panes[exact] = {pane = 8538394984457, program = "omp", focused = false, alert = false}
    local handler = e.handlers.title
    assert(handler, "Host title event refreshes the native roster")
    handler({pane = 360382115872777})
    r:event("pane_created", {pane = 8538394984457})
    assert(string.find(r.css, exact, 1, true), "New pane gets status styling without firing either timer")
    r.store.enabled = false
    r:event("command_finished", {pane = 8538394984457})
    equal(r.css, "", "Shared pause applies on a lifecycle event without a timer")
end)

test("window start installs persisted pane styles without a timer callback", function()
    local r = runtime()
    local _, exact = r:add(360382115872779, "pi", 8538394984459)
    r.handlers.window_start(r.cx)
    assert(string.find(r.css, exact, 1, true), "Window start installs styles directly")
end)

test("focused done and failed results are read immediately", function()
    for _, result in ipairs({"done", "failed"}) do
        local r = runtime()
        local pane = r:add(1)
        r:focus(pane)
        r:event("agent_finished", {pane = pane.pane, result = result})
        equal(read(r, pane), true, "Focused result read before polling")
        equal(pane.alert, false, "Completion does not change native attention")
        r:focus(nil)
        pane.alert = true
        r:tick()
        equal(read(r, pane), true, "Delayed attention remains read after leaving")
    end
end)

test("each new away result replaces a prior read result", function()
    local r = runtime()
    local pane = r:add(1)
    for _, result in ipairs({"failed", "done", "failed"}) do
        r:focus(pane)
        r:event("focus")
        equal(read(r, pane), true, "Prior result viewed")
        r:focus(nil)
        pane.alert = true
        r:event("agent_finished", {pane = pane.pane, result = result})
        equal(read(r, pane), nil, "New away result is unread")
        equal(pane.alert, true, "Native attention retained")
    end
end)

test("focus acknowledges only the focused pane", function()
    local r = runtime()
    local first = r:add(1)
    local second = r:add(2)
    first.alert, second.alert = true, true
    r:focus(first)
    r:event("focus")
    equal(read(r, first), true, "Focused pane read")
    equal(read(r, second), nil, "Other pane remains unread")
    r:focus(second)
    r:event("focus")
    equal(read(r, first), true, "Previous pane stays read")
    equal(read(r, second), true, "Second pane read independently")
end)

test("focused snapshot acknowledges only supported panes", function()
    local r = runtime()
    local first = r:add(1)
    local second = r:add(2)
    first.alert, second.alert = true, true
    r:focus(first)
    r:tick()
    equal(read(r, first), true, "Focused snapshot read")
    equal(read(r, second), nil, "Other snapshot remains unread")
end)

test("read persists across leaving and window reload", function()
    local r = runtime()
    local pane = r:add(1)
    pane.alert = true
    r:focus(pane)
    r:tick()
    r:focus(nil)
    r:boot()
    r:tick()
    equal(read(r, pane), true, "Read marker survives reload")
    equal(pane.alert, true, "Reload does not acknowledge native attention")
    r:event("agent_finished", {pane = pane.pane, result = "done"})
    equal(read(r, pane), nil, "New result resets persisted read")
end)

test("pane closure removes only its own persisted read", function()
    local r = runtime()
    local first = r:add(1)
    local second = r:add(2)
    r:focus(first); r:event("focus")
    r:focus(second); r:event("focus")
    r:event("pane_closed", {pane = first.pane})
    equal(read(r, first), nil, "Closed pane marker removed")
    equal(read(r, second), true, "Other pane marker retained")
end)

test("paused events still maintain per-pane read state", function()
    local r = runtime()
    local first = r:add(1)
    local second = r:add(2)
    r:command("pause")
    r:focus(first)
    r:event("agent_finished", {pane = first.pane, result = "failed"})
    equal(read(r, first), true, "Paused focused result read")
    r:focus(second)
    r:event("focus")
    equal(read(r, second), true, "Paused focus recorded")
    r:event("agent_finished", {pane = first.pane, result = "done"})
    equal(read(r, first), nil, "Paused away result replaces prior read")
    equal(read(r, second), true, "Other paused read preserved")
    r:command("resume")
    equal(read(r, first), nil, "Resume preserves unread result")
end)

test("shared pause crosses windows and survives reload without metadata reads", function()
    local e = environment()
    local first, second = runtime(e), runtime(e)
    first:add(1)
    second:add(2, "/bin/zsh")
    second.surfaces["2"] = {surface = {role = "omp.session"}}
    first:tick(); second:tick()
    assert(first.css ~= "" and second.css ~= "", "Enabled windows install styles")
    first:command("pause")
    for _, r in ipairs({first, second}) do
        r.cx.session.pane = function() error("Paused pane metadata unavailable") end
        r.cx.session.surface = function() error("Paused surface unavailable") end
    end
    second:tick()
    equal(first.css, "", "Initiating window removes styles")
    equal(second.css, "", "Other window observes pause")
    second:boot(); second:tick()
    equal(second.css, "", "Paused reload removes styles without metadata")
    equal(e.store.enabled, false, "Pause persisted in shared storage")
end)

test("resume is shared between windows", function()
    local e = environment({enabled = false})
    local first, second = runtime(e), runtime(e)
    first:tick(); second:tick()
    first:command("resume")
    second:tick()
    equal(e.store.enabled, true, "Resume persisted")
    assert(first.css ~= "" and second.css ~= "", "Both windows resume styles")
end)

test("new native panes and old OMP shells become eligible on refresh", function()
    local r = runtime()
    r:tick()
    local pane, exact = r:add(186951336460348, "/bin/zsh", 12345)
    pane.alert = true
    r:focus(pane)
    r:tick()
    equal(read(r, pane), nil, "Ordinary shell ignored")
    r.surfaces[exact] = {surface = {role = "omp.session"}}
    r:tick()
    equal(read(r, pane), true, "Old OMP shell identified after surface appears")
    equal(r.store["read:" .. exact], nil, "Read uses event SDK ID rather than native ID")
end)

test("direct executable basenames identify OMP and Pi without surfaces", function()
    for _, program in ipairs({"omp", "pi", "/opt/bin/omp", "/opt/bin/pi", "C:\\tools\\omp", "C:\\tools\\pi"}) do
        local r = runtime()
        local pane = r:add(1, program)
        pane.alert = true
        r:focus(pane)
        r.cx.session.surface = function() error("Direct executable needs no surface") end
        r:tick()
        equal(read(r, pane), true, "Supported executable " .. program)
    end
end)

test("unknown programs and unrelated shell surfaces remain unsupported", function()
    for _, program in ipairs({"unknown", "myomp", "/opt/bin/omp-helper", "pi.exe", "", null}) do
        local r = runtime()
        local pane, exact = r:add(1, program)
        pane.alert = true
        r:focus(pane)
        r.surfaces[exact] = {surface = {role = "omp.session"}}
        r:tick()
        equal(read(r, pane), nil, "Unsupported executable")
        equal(r.surface_reads, 0, "Unknown executables do not request surfaces")
    end
    for _, response in ipairs({null, {surface = null}, {surface = {role = "shell"}}}) do
        local r = runtime()
        local pane, exact = r:add(1, "zsh")
        pane.alert = true
        r:focus(pane)
        r.surfaces[exact] = response
        r:tick()
        equal(read(r, pane), nil, "Unrelated or absent shell surface")
    end
end)

test("other windows and closed native panes can be absent from a window lookup", function()
    local e = environment()
    local first, second = runtime(e), runtime(e)
    local pane = second:add(2)
    pane.alert = true
    second:focus(pane)
    first:tick(); second:tick()
    equal(read(second, pane), true, "Owning window can read its pane")
    second.panes["2"] = nil
    e.native = {}
    e:tick_host()
    first:tick(); second:tick()
    equal(#e.store["native-panes"], 0, "Closed pane removed from native roster")
end)

test("active status never mutates manual tab colors or creates legacy records", function()
    local r, tab = tab_fixture("purple")
    local pane = r:add(1)
    r:tick()
    tab.color = "orange"
    r:event("agent_finished", {pane = pane.pane, result = "failed"})
    r:tick()
    r:command("pause"); r:command("resume")
    equal(tab.color, "orange", "Manual tab color retained")
    equal(r.color_writes, 0, "No status color mutations")
    equal(r.store["tab:4:7"], nil, "No new restoration record")
end)

test("legacy migration restores applied colors and verifies the native result", function()
    for _, original in ipairs({"purple", null}) do
        local r, tab = tab_fixture("blue", {['tab:4:7'] = {original = original, applied = "blue"}})
        r:tick()
        equal(tab.color, if original == null then nil else original, "Original native color restored")
        equal(r.store["tab:4:7"], nil, "Verified migration clears record")
        equal(r.color_writes, 1, "One restore mutation")
        r:tick()
        equal(r.color_writes, 1, "Completed migration does not repeat")
    end
end)

test("legacy migration preserves a manual color changed since status applied", function()
    local r, tab = tab_fixture("orange", {['tab:4:7'] = {original = "purple", applied = "blue"}})
    r:tick()
    equal(tab.color, "orange", "Manual native color preserved")
    equal(r.color_writes, 0, "No restore over a manual color")
    equal(r.store["tab:4:7"], nil, "Obsolete record cleared")
end)

test("silent native restore rejection keeps the migration record for retry", function()
    local r, tab = tab_fixture("blue", {['tab:4:7'] = {original = "purple", applied = "blue"}})
    r.unaddressable = tab.id
    r:tick()
    equal(tab.color, "blue", "Rejected restore remains unchanged")
    equal(r.store["tab:4:7"].original, "purple", "Original retained after silent rejection")
    equal(r.store["tab:4:7"].applied, "blue", "Applied color retained after silent rejection")
    r.unaddressable = nil
    r:tick()
    equal(tab.color, "purple", "Later restore succeeds")
    equal(r.store["tab:4:7"], nil, "Successful retry clears record")
end)

test("paused migration restores legacy colors without agent or surface metadata", function()
    local r, tab = tab_fixture("blue", {enabled = false, ['tab:4:7'] = {original = "purple", applied = "blue"}})
    r.cx.session.pane = function() error("Pane unavailable") end
    r.cx.session.surface = function() error("Surface unavailable") end
    r:tick()
    equal(tab.color, "purple", "Legacy restore works during pause")
    equal(r.store["tab:4:7"], nil, "Paused migration verified")
end)

test("both launch commands preserve panes, cwd and launch preferences", function()
    for _, program in ipairs({"pi", "omp"}) do
        for _, placement in ipairs({"split", "replace_if_alone", "new_tab"}) do
            local r, original = tab_fixture("purple")
            local preferences = {agent_command = "omp --model custom", agent_placement = placement}
            local pane = r:add(1)
            pane.tab, pane.cwd = original.id, "/work/current project"
            r:focus(pane)
            local launched
            local action_count = 0
            r.cx.settings = {
                get = function(_, key) return preferences[key] end,
                set_many = function(_, patch)
                    for key, value in pairs(patch) do preferences[key] = value end
                end,
            }
            r.cx.actions = {run = function(_, action, ...)
                action_count += 1
                equal(action, "new_agent_block", "Native agent launch action")
                equal(select("#", ...), 0, "Launch sends no initial prompt or extra action payload")
                equal(preferences.agent_placement, "new_tab", "Launch creates a separate tab")
                local source = r.panes[tostring(r.focused)]
                local cwd = source.cwd
                local destination = original
                if preferences.agent_placement == "replace_if_alone" then
                    r.panes[tostring(r.focused)] = nil
                elseif preferences.agent_placement == "new_tab" then
                    destination = {id = 8, session = original.session}
                    table.insert(r.tabs, destination)
                end
                launched = r:add(2, preferences.agent_command)
                launched.tab, launched.cwd = destination.id, cwd
                r:focus(launched)
            end}
            r:command(if program == "pi" then "new_pi_tab" else "new_omp_tab")
            equal(r.panes["1"], pane, "Existing conversation preserved")
            equal(pane.tab, original.id, "Existing pane remains in its tab")
            equal(pane.cwd, "/work/current project", "Existing cwd preserved")
            equal(#r.tabs, 2, "Native launch creates another tab")
            equal(launched.tab, 8, "New conversation has its own tab")
            equal(r.focused, launched.pane, "New conversation receives focus")
            equal(launched.cwd, pane.cwd, "Native action inherits focused cwd")
            equal(launched.program, program, "Chosen executable has no initial prompt")
            equal(action_count, 1, "One native launch action")
            equal(preferences.agent_command, "omp --model custom", "Custom command restored")
            equal(preferences.agent_placement, placement, "Placement restored")
        end
    end
end)

test("both failed launch commands restore settings and propagate failure", function()
    for _, program in ipairs({"pi", "omp"}) do
        for _, placement in ipairs({"split", "replace_if_alone", "new_tab"}) do
            local r = runtime()
            local preferences = {agent_command = "omp --model custom", agent_placement = placement}
            r.cx.settings = {
                get = function(_, key) return preferences[key] end,
                set_many = function(_, patch)
                    for key, value in pairs(patch) do preferences[key] = value end
                end,
            }
            r.cx.actions = {run = function() error("Launch refused") end}
            local ok, err = pcall(function()
                r:command(if program == "pi" then "new_pi_tab" else "new_omp_tab")
            end)
            equal(ok, false, "Launch failure reported")
            assert(string.find(tostring(err), "Launch refused", 1, true), "Original launch error propagated")
            equal(preferences.agent_command, "omp --model custom", "Custom command restored after failure")
            equal(preferences.agent_placement, placement, "Placement restored after failure")
        end
    end
end)

return cases
