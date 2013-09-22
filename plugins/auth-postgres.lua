postgres = {}

local function check_connection()
    if not postgres.db or not postgres.db:ping() then
        local Server = plugin.ConfigGet('server')
        local Username = plugin.ConfigGet('username')
        local Password = plugin.ConfigGet('password')
        local Database = plugin.ConfigGet('database')
        local Port = tonumber(plugin.ConfigGet('port')) or 5432
        postgres.db = DBI.Connect('PostgreSQL', Database, Username, Password, Server, Port)
    end
    if not postgres.db then
        error("Could not connect to the PostgreSQL database!")
        return false
    end
    return true
end

plugin.AddHook('auth.GetLevel', 'GetLevel', function(Channel, Account)
    if check_connection() then
        local Statement = postgres.db:prepare("select _level from _level where _account = ? and _channel = ?")
        print(Account, Channel.Name)
        Statement:execute(Account, Channel.Name)
        for Row in Statement:rows(true) do
            return tonumber(Row._level)
        end
        return 0
    end
end)
