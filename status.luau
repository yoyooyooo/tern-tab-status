local colors = {"blue", "green", "yellow", "red"}

local function color(panes)
    local priority = 0
    for _, pane in ipairs(panes) do
        local rank = 0
        if pane.alert and (pane.result == "failed" or pane.error
            or (pane.exited ~= nil and pane.exited ~= 0)) then
            rank = 4
        elseif pane.state == "waiting_input" then
            rank = 3
        elseif pane.alert then
            rank = 2
        elseif pane.state == "working" then
            rank = 1
        end
        priority = math.max(priority, rank)
    end
    return colors[priority]
end

return {color = color}
