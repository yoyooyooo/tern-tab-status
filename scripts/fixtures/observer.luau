-- Read native state; never synthesize agent progress, attention or completion.
local root = tern.getenv("TERN_STATUS_VERIFY_DIR")
local revision = 0
local function snapshot(cx)
    revision += 1
    local value = {
        revision = revision,
        nonce = tern.json.decode(tern.fs.read(root .. "/snapshot-request.json")).nonce,
        agents = tern.json.array(cx.agents:list()), tabs = tern.json.array(cx.session:tabs()), panes = tern.json.array(cx.session:panes()),
        focused = cx.session:focused(),
        settings = {agent_command = cx.settings:get("agent_command"), agent_placement = cx.settings:get("agent_placement")},
    }
    tern.fs.write(root .. "/snapshot.json", tern.json.encode(value))
end
tern.command({id = "snapshot", title = "Verification: Capture native state", run = snapshot})
tern.command({id = "drive", title = "Verification: Arrange owned panes", run = function(cx)
    local request = tern.json.decode(tern.fs.read(root .. "/drive.json"))
    if request.op == "focus" then
        cx.layout:focus(request.pane)
    elseif request.op == "color" then
        cx.layout:color_tab(request.tab, request.color)
    elseif request.op == "move" then
        local ok, err = cx.layout:move_to_tab(request.pane, request.tab)
        if not ok then error(err) end
    elseif request.op == "settings" then
        cx.settings:set_many(request.values)
    else
        error("Unknown verification operation")
    end
    snapshot(cx)
end})
