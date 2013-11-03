plugin.AddCommand('at', 0, function(Username, Channel)
    if Channel.Name = '#hackerspace-pl' then
        return
    end
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

local function SayDue(Target, Channel)
    local Body, Code, Headers, Status = https.request('https://kasownik.hackerspace.pl/api/months_due/' .. Target .. '.json')
    if Code == 404 then
        Channel:Say("No such member.")
	return
    end
    if Code ~= 200 then
        error(string.format("Status code returned: %i", Code))
    end

    local Data = json.decode.decode(Body)
    if Data['status'] ~= 'ok' then
        error("No such member?")
    else
        local Due = Data['content']
	local Comment = ""
	if Due < 0 then
	    Comment = string.format("is %i months ahead. Cool!", -Due)
	elseif Due == 0 then
	    Comment = "has paid all his membership fees."
	elseif Due == 1 then
	    Comment = "needs to pay one membership fee."
	else
	    Comment = string.format("needs to pay %i membership fees.", Due)
	end
        Channel:Say(Target .. " " .. Comment)
    end
end

plugin.AddCommand('due', 1, function(Username, Channel, Target)
    if Channel.Name = '#hackerspace-pl' then
        return
    end
    SayDue(Target, Channel)
end, "Show months due for user.")

plugin.AddCommand('due-me', 0, function(Username, Channel)
    if Channel.Name = '#hackerspace-pl' then
        return
    end
    SayDue(Username, Channel)
end, "Show months due for speaker.")

Nagged = {}
plugin.AddHook('irc.Message', 'nag', function(Username, Channel, Message)
    if Channel.Name = '#hackerspace-pl' then
        return
    end
    local Target = Username:lower()
    if Target == 'enleth' then return end
    if Nagged[Target] == nil or Nagged[Target] < os.time() then
        local Body, Code, Headers, Status = https.request('https://kasownik.hackerspace.pl/api/months_due/' .. Target .. '.json')
        if Code == 200 then
            local Data = json.decode.decode(Body)
            if Data['content'] > 0 then
                Nagged[Target] = os.time() + 60 * 60 * 24
                local Months = 'months'
                if Data['content'] == 0 then
                    Months = 'month'
                end
                Channel:Say(string.format('%s: pay your membership fees! you are %i %s behind!', Username, Data['content'], Months))
            end
        end
    end
end)

plugin.AddCommand('mana', 0, function(Username, Channel)
    if Channel.Name = '#hackerspace-pl' then
        return
    end
    local Body, Code, Headers, Status = https.request('https://kasownik.hackerspace.pl/api/mana.json')
    if Code ~= 200 then
        error(string.format("Status code returned: %i", Code))
    end

    local Data = json.decode.decode(Body)
    local Required = Data['content']['required']
    local Paid = Data['content']['paid']
    local Updated = Data['modified']
    Channel:Say(string.format("%i paid, %i required (last updated %s)", Paid, Required, Updated))
end, "Show Hackerspace mana (due fees in total.")

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

