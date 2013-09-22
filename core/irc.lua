
irc = {}
irc.Channel = {}
irc.Channel.__index = irc.Channel

function irc.Channel:Say(Message)
    self._irc:Say(self.Name, Message)
end

function irc:ReceiveData(socket)
    -- Two seconds look okay for receiving a rest of line
    socket:settimeout(2)
    local Data, Error = socket:receive('*l')
    if Error then
        error('Could not receive IRC line: ' .. Error)
    end
    hook.Call('debug', Data)
    local Prefix, Command, Arguments
    if Data:sub(1, 1) == ':' then
        local Pattern = ':([^ ]+) +([^ ]+) *(.*)'
        Prefix, Command, Arguments = string.match(Data, Pattern)
    else
        local Pattern = '([^ ]+) *(.*)'
        Prefix = nil
        Command, Arguments = string.match(Data, Pattern)
    end
    if Command == nil then
        error('Invalid IRC line: ' .. Data)
    end

    self:HandleCommand(Prefix, Command, Arguments)
end

function irc:ParseArguments(Arguments)
    local Parts = {}
    local Current = ""
    local GrabRest = false
    for c in Arguments:gmatch('.') do
        if GrabRest then
            Current = Current .. c
        elseif c == ' ' then
            if Current ~= '' then
                Parts[#Parts + 1] = Current
                Current = ''
            end
        else
            if Current == '' and c == ':' then
                -- the rest is a single part, with spaces
                GrabRest = true
            else
                Current = Current .. c
            end
        end
    end
    Parts[#Parts + 1] = Current
    return Parts
end

function irc:HandleCommand(Prefix, Command, Arguments)
    local Number = tonumber(Command)
    local Arguments = self:ParseArguments(Arguments)
    if Command == 'PING' then
        self:_Send('PONG ' .. Arguments[1])
    elseif Command == 'NOTICE' then
        local Target, Message = unpack(Arguments)
        hook.Call('irc.Notice', Target, Message)
    elseif Command == 'MODE' then
        local Target, Mode = unpack(Arguments)
        hook.Call('irc.Mode', Target, Mode)
    elseif Command == 'PRIVMSG' then
        local Target, Message = unpack(Arguments)
        local Username = Prefix:match('([^!]+)!.*')
        if Target == self._nickname then
            hook.Call('irc.PrivateMessage', Username, Message)
        else
            hook.Call('irc.Message', Username, self._channels[Target], Message)
        end
    elseif Number and (400 <= Number) and (Number < 500) then
       if Number == 433 then
            -- Nickname already in use
            local New = hook.Call('irc.NicknameInUser', self._nickname)
            if New and New ~= self._nickname then
                self._nickname = New
            else
                self._nickname = self._nickname .. '_'
            end
            self:SetNick(self._nickname)
       end
    elseif Number and (Number >= 300) and (Number < 400) then
        -- IRC server response. some parts of us might be looking for these
        if self._response_hooks[Number] ~= nil then
            for K, Callback in pairs(self._response_hooks[Number]) do
                if Callback(unpack(Arguments)) ~= false then
                    self._response_hooks[Number][K] = nil
                end
            end
        end
    end
end

function irc:OnResponse(Response, Callback)
    if type(Response) ~= 'number' then
        error("Watched response is not a number.")
    end
    if Response >= 300 and Response < 400 then
        self._response_hooks[Response] = self._response_hooks[Response] or {}
        local Count = #self._response_hooks[Response]
        self._response_hooks[Response][Count + 1] = Callback
    else
        error("Watched response is not a 3xx response.")
    end
end

function irc:_Send(message)
    self.Socket:send(message..'\r\n')
end

function irc:SetNick(nickname)
    self:_Send('NICK '..nickname)
    hook.Call('info', 'Changing nickname to ' .. self._nickname)
end

function irc:LoginUser(username, realname)
    self:_Send('USER ' .. username .. ' 0 * :' .. realname)
    hook.Call('info', 'Logging in as ' .. username .. ' ' .. realname)
end

function irc:Say(target, message)
    self:_Send('PRIVMSG ' .. target .. ' :' .. message)
end

function irc:Join(channel)
    local Channel = setmetatable({}, irc.Channel)
    Channel.Name = channel
    Channel.Topic = ""
    Channel.Members = {}
    Channel._irc = self
    self._channels[channel] = Channel

    self:_Send('JOIN ' .. channel)
    self:OnResponse(332, function(Nick, _channel, Topic)
        -- Channel topic
        if _channel ~= channel then
            return false
        end
        Channel.Topic = Topic
        hook.Call('irc.ChannelTopic', Channel)
        return true
    end)

    local MoreNicks = true
    self:OnResponse(353, function(Nick, Type, _channel, Members)
        if not MoreNicks then
            return true
        end
        if _channel ~= channel then
            return false
        end
        for Member in Members:gmatch("%S+") do
            print(Member)
            local Flag, Name = Member:match('([~@%&]?)(.+)')
            local Data = {}
            Data.Name = Name
            Data.Flags = Flags
            Channel.Members[Name] = Data
        end
        return true
    end)
    self:OnResponse(366, function()
        MoreNicks = false
        hook.Call('irc.ChannelNames', Channel)
    end)
end

function irc:Connect(server, port, nickname, username, realname)
    self._nickname = nickname
    self._username = username
    self._realname = realname

    self._channels = {}
    self._response_hooks = {}

    -- Connection procedure (callback hell!)
    local FinishedInitialNotices = function()
        hook.Remove('irc.Notice', 'irc.Connect')
        hook.Add('irc.Mode', 'irc.Connect', function(Target, Mode)
            if Target == self._nickname then
                hook.Remove('irc.Mode', 'irc.Connect')
                hook.Call('irc.Connected')
            end
        end)
        self:SetNick(self._nickname)
        self:LoginUser(username, realname)
    end
    hook.Add('irc.Notice', 'irc.Connect', function(Target, Message)
        reactor:SetTimer('irc.Connect.NoticeTimeout', 2, FinishedInitialNotices)
    end)

    local Socket = reactor:TCPConnect(server, port, function(socket)
        irc:ReceiveData(socket)
    end)
    self.Socket = Socket
end
