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
end

function bot:OnChannelMessage(Username, Channel, Message)
    if Message:sub(1,#self._prefix) == self._prefix then
        local String = Message:sub(#self._prefix + 1)
        print(String)
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
            if #Arguments ~= CommandData.Arguments then
                Channel:Say(string.format("Command '%s' expects '%i' arguments, got '%i'.",
                    Command, CommandData.Arguments, #Arguments))
            else
                CommandData.Callback(Username, Channel, unpack(Arguments))
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
