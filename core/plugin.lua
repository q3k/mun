-- An isolated API for plugins
-- These plugins are not yet made to be a secure sandbox, as hooking
-- into signal might be destructive or reveal sensitive data.
-- The goal is to be able to unload a plugin and remove all its' hooks
-- and commands.

local Plugins = {}

plugin = {}
local API = {}

-- All these functions start with the 'plugin_id' argument, which
-- will be auto-bound to the plugin name when called from a plugin.
function API.HookAdd(plugin_id, event_name, hook_name, callback)
    local HookName = plugin_id .. ':' .. hook_name
    local PluginHooks = Plugins[plugin_id].Hooks
    PluginHooks[#PluginHooks + 1] = HookName
    hook.Add(event_name, HookName, function(...)
        local Args = {...}
        local Success, Message = pcall(callback(unpack(Args)))
        if not Success then
            hook.Call("plugin.HookCallFailed", HookName, Message)
            return nil
        else
            return Message
        end
    end)
end

function API.CommandAdd(plugin_id, command_name, arity, callback, access, help)
    bot:AddCommand(command_name, arity, callback, access, help)
    local PluginCommands = Plugins[plugin_id].Commands
    PluginCommands[#PluginCommands + 1] = command_name
end

function API.Register(plugin_id, plugin_name, version, url, author)
    local Plugin = Plugins[plugin_id]
    Plugin.Name = plugin_name
    Plugin.Version = Version
    Plugin.URL = url
    Plugin.Author = author

end

function plugin.Create(plugin_id)
    local Plugin = {}
    Plugin.Hooks = {}
    Plugin.Commands = {}

    Plugin.ID = plugin_id
    Plugin.Name = ""
    Plugin.Version = 1.0
    Plugin.URL = ""
    Plugin.Author = "Nameless Wonder"

    Plugins[plugin_id] = Plugin
    Plugins[plugin_id].Env = plugin.PrepareEnvironment(plugin_id)
end

function plugin.PrepareEnvironment(plugin_id)
    local function BindPluginID(f)
        return function(...)
            local Args = {...}
            return f(plugin_id, unpack(Args))
        end
    end
    
    local Env = {}
    Env.table = require('table')
    Env.string = require('string')
    Env.json = require('json')

    Env.plugin = {}
    for K, F in pairs(API) do
        Env.plugin[K] = BindPluginID(F)
    end

    return Env
end

function plugin.RunCode(plugin_id, code)
    if not Plugins[plugin_id] then
        plugin.Create(plugin_id)
    end

    if code:byte(1) == 27 then
        return nil, "Refused to load bytecode."
    end
    local Function, Message = loadstring(code)
    if not Function then
        return nil, Message
    end
    setfenv(Function, Plugins[plugin_id].Env)
    return pcall(Function)
end
