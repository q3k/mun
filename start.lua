require('core.hook')
require('core.reactor')
require('core.irc')
require('core.bot')
require('core.plugin')

require('socket')
local https = require('ssl.https')
require('json')

hook.Add('info', 'repl-info', function(Message)
    print('INFO: ' .. Message)
end)

hook.Add('debug', 'repl-debug', function(Message)
    print('DEBUG: ' .. Message)
end)

hook.Add('irc.Connected', 'repl-connected', function()
    irc:Join('#hackerspace-pl-bottest')
end)

reactor:Initialize()
bot:Initialize(irc, ',')
plugin.AddRuntimeCommands()
--[[bot:AddCommand('at', 0, function(Username, Channel)
    local Body, Code, Headers, Status = https.request('https://at.hackerspace.pl/api')
    if Code ~= 200 then
        error(string.format("Status code returned: %i", Code))
    end
    local Data = json.decode.decode(Body)
    local Users = {}
    for K, User in pairs(Data.users) do
        Users[#Users + 1] = User.login
    end
    Channel:Say(table.concat(Users, ','))

end, "Show who's at the Warsaw Hackerspace.")]]--

irc:Connect('irc.freenode.net', 6667, 'moonspeak', 'moonspeak', 'moonspeak')
reactor:Run()
