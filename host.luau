local last = nil
local function publish()
    local ids = {}
    for _, pane in ipairs(tern.pane.list()) do
        table.insert(ids, string.format("%.0f", pane.pane))
    end
    table.sort(ids)
    local signature = table.concat(ids, ",")
    if signature ~= last then
        tern.kv.set("native-panes", ids)
        last = signature
    end
end
local function poll()
    publish()
    tern.timer(750, poll)
end
for _, event in ipairs({"command_started", "command_finished", "cwd", "title", "pane_exited"}) do
    tern.on(event, publish)
end
poll()
