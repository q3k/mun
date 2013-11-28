local Map = {}
local Pending = {}

plugin.AddHook('auth.GetAccount', 'GetAccount', function(IRC, Username)
    if Map[Username] == nil then
        if not Pending[Username] then
            -- create and event and wait for it
            local Event = plugin.NewEvent()
            Pending[Username] = Event
            IRC:Whois(Username)
        end
        return Pending[Username]:Wait()
    end
    return Map[Username]
end)

plugin.AddHook('irc.GetResponse330', 'WHOISResponse', function(_, Username, Account, Message)
    Map[Username] = Account
    if Pending[Username] ~= nil then
        Pending[Username]:Fire(Account)
    end
end)

--[[ plugin.AddHook('irc.ChannelNames', 'ScanChannelUsers', function(Channel)
    for Nick, Member in pairs(Channel.Members) do
        if not Pending[Nick] then
            Channel:Whois(Nick)
            Pending[Nick] = true
        end
    end
end) ]]--
