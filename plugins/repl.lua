
local function DeepCopy(t)
    local Copied = {}
    local Result = {}
    local function Internal(Out, In)
        for K, V in pairs(In) do
            local Type = type(V)
            if Type == "string" or Type == "function" or Type == "number" then
                Out[K] = V
            elseif Type == "table" then
                if Copied[V] ~= nil then
                    Out[K] = Copied[V]
                else
                    Copied[V] = {}
                    Internal(Copied[V], V)
                    Out[K] = Copied[V]
                end
            end
        end
        return Out
    end
    Internal(Result, t)
    return Result
end

plugin.AddCommand('eval', -1, function(User, Channel, String)
    local Function, Message = loadstring(String)
    if not Function then
        Channel:Say("Parse error: " .. Message)
        return
    end
    local Env = DeepCopy(_G)
    Env.plugin = nil
    Env.loadstring = nil
    Env.pcall = nil
    Env.setfenv = nil
    Env._G = Env
    Env.DBI = nil
    Env.https = nil
    Env.json = nil
    Env.print = function(...)
        local Args = {...}
        local Output = table.concat(Args, "\t")
        Channel:Say("stdout: " .. Output)
    end

    setfenv(Function, Env)
    local Result, Message = pcall(Function)
    if Result then
        Channel:Say("OK -> " .. tostring(Message))
    else
        Channel:Say("Error -> " .. tostring(Message))
    end
end, "Runs a Lua command in a sandbox.", 10)
