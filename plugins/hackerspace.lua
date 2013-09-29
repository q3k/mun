plugin.AddCommand('at', 0, function(Username, Channel)
    local Body, Code, Headers, Status = https.request('https://at.hackerspace.pl/api')
    if Code ~= 200 then
        error(string.format("Status code returned: %i", Code))
    end

    local Data = json.decode.decode(Body)
    local Users = {}
    for K, User in pairs(Data.users) do
        Users[#Users + 1] = User.login
    end
    if #Users == 0 then
        Channel:Say("Trochę Łotwa. Nawet zimnioka nie ma.")
    else
        Channel:Say(table.concat(Users, ', '))
    end
end, "Show who's at the Warsaw Hackerspace.")

plugin.AddCommand('describe', 1, function(Username, Channel, Term)
    local db = plugin.DBOpen('main')
    local Header = false
    local Counter = 0
    for Row in db:Query('select _oid::text from _term where lower(_name) = lower(?);', Term) do
        local Oid = Row._oid
        for Row2 in db:Query('select _text from _entry where _term_oid = ?', Oid) do
            if not Header then
                Channel:Say(string.format('I heard "%s" is:', Term))
                Header = true
            end           
            local Text = Row2._text
            Channel:Say(string.format('[%i] ', Counter) .. Text)
            Counter = Counter + 1
        end
    end
    if not Header then
        Channel:Say("No such term!")
    end

end, "Describe a saved term.")

plugin.AddHook('bot.UnknownCommand', 'DescribeTerm', function(Username, Channel, Command, Arguments)
    local db = plugin.DBOpen('main')
    for Row in db:Query('select _oid::text from _term where lower(_name) = lower(?);', Command) do
        local Oid = Row._oid
        for Row2 in db:Query('select _text from _entry where _term_oid = ? order by random() limit 1;', Oid) do
            Channel:Say(Row2._text)
            return true
        end
    end
end)


plugin.AddCommand('op', 1, function(Username, Channel, Target)
    irc:_Send(string.format("MODE %s +o %s", Channel, Target))
end, "Give operator status to someone on the channel.", 40)
