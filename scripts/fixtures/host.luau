-- Only the isolated verification daemon installs this filter.
local root = tern.getenv("TERN_STATUS_VERIFY_DIR")
local config = tern.json.decode(tern.fs.read(root .. "/host-config.json"))
local function quote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end
tern.on("spawn", function(spec)
    local last = spec.args[#spec.args]
    if last ~= "omp" and last ~= "pi" then return spec end
    local host = last
    local selected = config[host]
    local args = {quote(selected.executable)}
    for _, arg in ipairs(selected.args) do table.insert(args, quote(arg)) end
    spec.args[#spec.args] = table.concat(args, " ")
    for key, value in pairs(config.env) do spec.env[key] = value end
    spec.env.TERN_STATUS_VERIFY_HOST = host
    spec.env.PI_CODING_AGENT_DIR = selected.agentDir
    spec.env.OMP_CODING_AGENT_DIR = selected.agentDir
    spec.env.PI_CODING_AGENT_SESSION_DIR = selected.sessionDir
    spec.env.TERN_DAEMON_SOCKET = config.daemonSocket
    return spec
end)
