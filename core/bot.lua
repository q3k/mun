-- All bot-like behaviour (response to commands, etc)

bot = {}

function bot:Initialize(IRC, Prefix)
    self._irc = IRC
    self._prefix = Prefix
    self._commands = {}

    hook.Add('irc.Message', 'bot.OnChannelMessage', function(Username, Channel, Message)
        local Success, Error = pcall(function()
            self:OnChannelMessage(Username, Channel, Message)
        end)
        if not Success then
            Channel:Say("Whoops! Error when executing OnChannelMessage: " .. Error)
        end
    end)
    self:AddCommand('eval-core', -1, function(Username, Channel, String)
        local Function, Message = loadstring(String)
        if not Function then
            Channel:Say("Parse error: " .. Message)
            return
        end
        local Status, Message = pcall(Function)
        if not Status then
            Channel:Say("Error -> " .. Message)
        else
            Channel:Say("OK -> " .. tostring(Message))
        end
    end, "Runs a Lua command in the bot context.", 100)
end

function bot:OnChannelMessage(Username, Channel, Message)
    if Message:sub(1,#self._prefix) == self._prefix then
        local String = Message:sub(#self._prefix + 1)
        local Command
        local Arguments = {}
        for Part in String:gmatch("%S+") do
            if Command == nil then
                Command = Part
            else
                Arguments[#Arguments + 1] = Part
            end
        end

        if not self._commands[Command] then
            Channel:Say("Unknown command '" .. Command .. "'.")
        else
            local CommandData = self._commands[Command]
            if #Arguments ~= CommandData.Arguments and CommandData.Arguments ~= -1 then
                Channel:Say(string.format("Command '%s' expects '%i' arguments, got '%i'.",
                    Command, CommandData.Arguments, #Arguments))
            else
                -- -1 means we want a raw string
                if CommandData.Arguments == -1 then
                    if #Arguments < 1 then
                        Channel:Say("Please provide an argument.")
                        return
                    end
                    Arguments = { table.concat(Arguments, ' ') }
                end
                local RequiredAccess = CommandData.Access
                if RequiredAcess == 0 then
                    CommandData.Callback(Username, Channel, unpack(Arguments))
                    return
                end
                local Account = hook.Call("auth.GetAccount", irc, Username)
                if not Account then
                    Channel:Say("Please identify with NickServ.")
                    return
                end
                local UserAccess = hook.Call("auth.GetLevel", Channel, Account)
                if not UserAccess then
                    Channel:Say("Could not run command because auth backend is missing.")
                    return
                end
                if UserAccess >= RequiredAccess then
                    CommandData.Callback(Username, Channel, unpack(Arguments))
                else
                    Channel:Say(string.format("Unsufficient access level (%i required).", RequiredAccess))
                end
            end
        end
    end
end

function bot:AddCommand(Name, Arguments, Callback, Help, Access)
    local Command = {}
    Command.Callback = Callback
    Command.Access = Access or 0
    Command.Help = Help or "No help available."
    Command.Arguments = Arguments
    self._commands[Name] = Command
end

function bot:RemoveCommand(Name)
    self._commands[Name] = nil
end
