hook = {}
hook.Hooks = {}

function hook.Add(event_name, hook_name, callback)
    if hook.Hooks[event_name] == nil then
        hook.Hooks[event_name] = {}
    end
    hook.Hooks[event_name][hook_name] = callback
end

function hook.Call(event_name, ...)
    local Args = {...}
    if hook.Hooks[event_name] == nil then
        return
    end
    for K, Function in pairs(hook.Hooks[event_name]) do
        if type(Function) == 'function' then
            local Return = Function(unpack(Args))
            if Return ~= nil then
                return Return
            end
        end
    end
end

function hook.Remove(event_name, hook_name)
    if hook.Hooks[event_name] == nil then
        return
    end
    hook.Hooks[event_name][hook_name] = nil
end
