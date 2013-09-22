-- An isolated API for plugins
-- These plugins are not yet made to be a secure sandbox, as hooking
-- into signal might be destructive or reveal sensitive data.
-- The goal is to be able to unload a plugin and remove all its' hooks
-- and commands.

require('lfs')

plugin = {}
plugin.Plugins = {}
plugin.API = {}

local Plugins = plugin.Plugins
local API = plugin.API


-- All these functions start with the 'plugin_id' argument, which
-- will be auto-bound to the plugin name when called from a plugin.
function API.AddHook(plugin_id, event_name, hook_name, callback)
    local HookName = plugin_id .. ':' .. hook_name
    local PluginHooks = Plugins[plugin_id].Hooks

    local HookInfo = {}
    HookInfo.EventName = event_name
    HookInfo.HookName = HookName

    PluginHooks[#PluginHooks + 1] = HookInfo
    hook.Add(event_name, HookName, function(...)
        local Args = {...}
        local Success, Message = pcall(callback, unpack(Args))
        if not Success then
            hook.Call("plugin.HookCallFailed", HookName, Message)
            return nil
        else
            return Message
        end
    end)
end

function API.Sleep(plugin_id, Delay)
    reactor:Sleep(Delay)
end


function API.WaitForEvent(plugin_id, Event)
    reactor:WaitForEvent(Event)
end

function API.Event(plugin_id, Event)
    reactor:Event(Event)
end


function API.AddCommand(plugin_id, command_name, arity, callback, access, help)
    bot:AddCommand(command_name, arity, function(...)
        plugin.Quota(5)
        local Result = callback(...)        
        debug.sethook()
        return Result
    end, access, help)
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

function API.ConfigGet(plugin_id, Key)
    return config:Get("plugin-" .. plugin_id, Key)
end

function plugin.Quota(seconds)
    local Start = os.time()
    debug.sethook(function()
        if debug.gethook() == nil then
            -- Race condition - somebody already removed us.
            return
        end
        if os.time() - Start > seconds then
            debug.sethook()
            error("Time quota exceeded.")
        end
    end, "", 1)
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
    local function BindPluginID(f)
        return function(...)
            local Args = {...}
            return f(plugin_id, unpack(Args))
        end
    end

    local Env = {}
    Env.table = DeepCopy(require('table'))
    Env.string = DeepCopy(require('string'))
    Env.json = DeepCopy(require('json'))
    Env.DBI = DeepCopy(require('DBI'))
    Env.print = print
    Env.error = error
    Env.tonumber = tonumber
    Env.tostring = tostring
    Env.pcall = pcall
    Env.type = type
    Env.loadstring = function(s)
        if s:byte(1) == 27 then
            return nil, "Refusing to load bytecode"
        else
            return loadstring(s)
        end
    end
    Env.setfenv = setfenv
    Env.pairs = pairs
    Env._G = Env

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
        if not Name:match('([a-zA-Z0-9%-_]+)') then
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

function plugin.Discover()
    for Filename in lfs.dir('plugins/') do
        local FullFilename = 'plugins/' .. Filename
        local Attributes = lfs.attributes(FullFilename)
        if Attributes.mode == 'file' and FullFilename:sub(-4) == '.lua' then
            local PluginName = Filename:sub(1, -5)
            hook.Call('info', 'Loading plugin ' .. PluginName)

            local File, Message =  io.open(FullFilename)
            if not File then
                hook.Call('info', 'Skipping: ' .. Message)
            else
                local Data = File:read('*a')
                local Success, Message = plugin.RunCode(PluginName, Data)
                if not Success then
                    error(string.format("Could not load plugin %s: %s.", PluginName, Message))
                end
            end
        end
    end
end
