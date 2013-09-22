config = {}

function config:Load(filename)
    local File, Message = io.open(filename, "r")
    if not File then
        error("Could not open config file: " .. Message)
    end

    self.Sections = {}
    local CurrentSection = "Default"
    self.Sections[CurrentSection] = {}
    
    local Data = File:read('*a')
    Data:gsub("(.-)\r?\n", function(line)
        local Line = line:gsub("(#.*)", "")
        Line = Line:gsub("^%s*(.-)%s*$", "%1")
        if Line:len() == 0 then
            return
        end
        local Section = Line:match("%[([a-zA-Z0-9%-]+)%]")
        if Section ~= nil then
            CurrentSection = Section
            self.Sections[CurrentSection] = {}
        else
            local Key, Value = Line:match("([^= ]+) *= *([^=]+)")
            print(Key,Value)
            if Key ~= nil and Value ~= nil then
                self.Sections[CurrentSection][Key] = Value
            end
        end
    end)
end


function config:Get(Section, Key)
    if self.Sections[Section] == nil then
        return nil
    end
    return self.Sections[Section][Key]
end
