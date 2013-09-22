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
function API.AddHook(plugin_id, event_name, hook_name, callback)
    local HookName = plugin_id .. ':' .. hook_name
    local PluginHooks = Plugins[plugin_id].Hooks

    local HookInfo = {}
    HookInfo.EventName = event_name
    HookInfo.HookName = HookName

    PluginHooks[#PluginHooks + 1] = Info
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

function API.AddCommand(plugin_id, command_name, arity, callback, access, help)
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

function API.CurrentTime(plugin_id)
    return os.time()
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

function plugin.Unload(plugin_id)
    if Plugins[plugin_id] == nil then
        error("No such plugin.")
    end
    local Plugin = Plugins[plugin_id]
    local HooksRemoved = 0
    local CommandsRemoved = 0
    for K, HookInfo in pairs(Plugin.Hooks) do
        hook.Remove(HookInfo.EventName, HookInfo.HookName)
        HooksRemoved = HooksRemoved + 1
    end
    for K, CommandName in pairs(Plugin.Commands) do
        bot:RemoveCommand(CommandName)
        CommandsRemoved = CommandsRemoved + 1
    end
    Plugins[plugin_id] = nil
    return HooksRemoved, CommandsRemoved
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


function plugin.AddRuntimeCommands()
    bot:AddCommand('plugin-load', 1, function(Username, Channel, Name)
        if not Name:match('([a-zA-Z0-9\-_]+)') then
            Channel:Say("Invalid plugin name!")
            return
        end
        if Plugins[Name] ~= nil then
            Channel:Say(string.format("Plugin %s already loaded!", Name))
            return
        end
        local Filename = "plugins/" .. Name .. ".lua"
        local File, Message = io.open(Filename, 'r')
        if not File then
            Channel:Say(string.format("Could not open plugin file %s: %s", Filename, Message))
            return
        end
        local Data = File:read('*a')
        local Success, Message = plugin.RunCode(Name, Data)
        if not Success then
            Channel:Say(string.format("Could not run plugin code: " .. Message))
            return
        end
        Channel:Say(string.format("Loaded plugin %s succesfully (%i bytes).", Name, #Data))
    end, "Load a plugin from the plugins/ directory.", 100)
    bot:AddCommand('plugin-unload', 1, function(Username, Channel, Name)
        if Plugins[Name] ~= nil then
            local Hooks, Commands = plugin.Unload(Name)
            Channel:Say(string.format("Plugin unloaded (removed %i hooks and %i commands).", Hooks, Commands))
        else
            Channel:Say("Plugin wasn't loaded.")
        end
    end, "Unload a previously loaded plugin.", 100)
end
