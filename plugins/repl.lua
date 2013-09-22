plugin.AddCommand('eval', -1, function(User, Channel, String)
    local Function, Message = loadstring(String)
    if not Function then
        Channel:Say("Parse error: " .. Message)
        return
    end
    local Env = {}
    for K, V in pairs(_G) do
        Env[K] = V
    end
    Env.plugin = nil
    Env.loadstring = nil
    Env.pcall = nil
    Env.setfenv = nil
    Env._G = Env

    setfenv(Function, Env)
    local Result, Message = pcall(Function)
    if Result then
        Channel:Say("OK -> " .. tostring(Message))
    else
        Channel:Say("Error -> " .. tostring(Message))
    end
end, "Runs a Lua command in a sandbox.", 10)
