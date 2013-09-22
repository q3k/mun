local Map = {}
local Pending = {}

plugin.AddHook('auth.GetAccount', 'GetAccount', function(IRC, Username)
    if Map[Username] == nil then
        if not Pending[Username] then
            IRC:Whois(Username)
            Pending[Username] = true
        end
        plugin.WaitForEvent("whois-"..Username)
    end
    return Map[Username]
end)

plugin.AddHook('irc.GetResponse330', 'WHOISResponse', function(_, Username, Account, Message)
    Map[Username] = Account
    plugin.Event("whois-" .. Username)
end)

plugin.AddHook('irc.ChannelNames', 'ScanChannelUsers', function(Channel)
    for Nick, Member in pairs(Channel.Members) do
        if not Pending[Nick] then
            Channel:Whois(Nick)
            Pending[Nick] = true
        end
    end
end)
