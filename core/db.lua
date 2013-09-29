db = {}

db.Connection = {}
db.Connection.__index = db.Connection
db.Connections = {}

db.Open = function(Handle)
    if db.Connections[Handle] then
        return db.Connections[Handle]
    end

    local SectionName = 'db-' .. Handle
    local Backend = config:Get(SectionName, 'backend')
    local Server = config:Get(SectionName, 'server')
    local Port = tonumber(config:Get(SectionName, 'port'))
    local Database = config:Get(SectionName, 'database')
    local Username = config:Get(SectionName, 'username')
    local Password = config:Get(SectionName, 'password')

    if not Backend then
        error("Server backend not specified.")
    end

    local Table = setmetatable({}, db.Connection)
    Table.DB = DB
    Table.Name = Handle
    Table.Settings = {
        Backend = Backend,
        Server = Server,
        Port = Port,
        Database = Database,
        Username = Username,
        Password = Password
    }
    return Table
end

function db.Connection:Check()
    if not self.DB or not self.DB:ping() then
        local DB = DBI.Connect(self.Settings.Backend, self.Settings.Database,
            self.Settings.Username, self.Settings.Password, self.Settings.Server,
            self.Settings.Port)
        if not DB then
            error("Could not connect to database.")
        end
        self.DB = DB
    end
end

function db.Connection:Query(Query, ...)
    self:Check()

    local Statement = self.DB:prepare(Query)
    local Args = {...}
    Statement:execute(unpack(Args))
    if #Query > 6 and Query:sub(1,6):lower() == 'select' then
        return Statement:rows(true)
    end
end
