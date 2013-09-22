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
        Channel:Say(table.concat(Users, ','))
    end
end, "Show who's at the Warsaw Hackerspace.")
