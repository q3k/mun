require('core.hook')
require('core.config')
require('core.reactor')
require('core.irc')
require('core.bot')
require('core.plugin')

hook.Add('info', 'repl-info', function(Message)
    print('INFO: ' .. Message)
end)

hook.Add('debug', 'repl-debug', function(Message)
    print('DEBUG: ' .. Message)
end)

hook.Add('plugin.HookCallFailed', 'repl-debug', function(Name, Message)
    print(string.format("Plugin hook call failed! %s: %s", Name, Message))
end)

hook.Add('irc.Connected', 'repl-connected', function()
    print("Joining...")
    irc:Join('#hackerspace-pl-bottest')
end)

config:Load('moonspeak.ini')
local Server = config:Get('irc', 'server')
local Port = tonumber(config:Get('irc', 'port')) or 6667
local Nickname = config:Get('irc', 'nickname')
local Username = config:Get('irc', 'username')
local Realname = config:Get('irc', 'realname')

reactor:Initialize()
bot:Initialize(irc, '~')
plugin.AddRuntimeCommands()
plugin.Discover()
irc:Connect(Server, Port, Nickname, Username, Realname)
reactor:Run()
