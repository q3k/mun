postgres = {}

plugin.AddHook('auth.GetLevel', 'GetLevel', function(Channel, Account)
    local DB = plugin.DBOpen('auth')
    local Query = DB:Query("select _level from _level where _account = ? and _channel = ?",
        Account, Channel.Name)
    for Row in Query do
        return tonumber(Row._level)
    end
    return 0
end)
