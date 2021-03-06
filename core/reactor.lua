local socket = require('socket')
local coroutine = require('coroutine')

reactor = {}

function reactor:Initialize(quantum)
    self._read_sockets = {}
    self._write_sockets = {}
    self._quantum = quantum or 0.1
    self._quit = false

    self._co_sleep = {}
    self._co_event = {}
    self._coroutines = {}

    self._timers = {}
    self._events = {}
end

function reactor:Quit()
    self._quit = true
end

function reactor:Sleep(time)
    local co = coroutine.running()
    if co == nil then
        socket.sleep(time)
        return
    end
    self._co_sleep[co] = os.time() + time
    coroutine.yield()
end

reactor.Event = {}
function reactor.Event:Wait()
    if coroutine.running() == nil then
        error("Main thread waiting for event... wtf?")
    end
    self.Waiting[#self.Waiting + 1] = coroutine.running()
    local Status, Data = coroutine.yield()
    if Status == false then
        -- exception!
        error(Data)
    end
    return unpack(Data)
end

function reactor.Event:Fire(...)
    local Data = {...}
    -- make a local copy of the old waiters, and clear the new ones
    local Waiters = {}
    for i, Coroutine in pairs(self.Waiting) do
        Waiters[#Waiters + 1] = Coroutine
    end
    self.Waiting = {}
    for i, Coroutine in pairs(Waiters) do
        coroutine.resume(Coroutine, true, Data)
    end
end

function reactor.Event:Destroy()
    -- destroy all waiters
    for i, Coroutine in pairs(self.Waiting) do
        coroutine.resume(Coroutine, false, "Coroutine destroyed.")
    end
    self.Reactor._events[self.Identifier] = nil
end

function reactor:NewEvent()
    local Table = {}
    Table.Identifier = #self._events + 1
    Table.Reactor = self
    Table.Waiting = {}
    setmetatable(Table, reactor.Event)
    reactor.Event.__index = reactor.Event

    self._events[Table.Identifier] = Identifier
    return Table
end


function reactor:Spawn(f, ...)
    local Args = {...}
    local co = coroutine.create(function() f(unpack(Args)) end)
    self._coroutines[#self._coroutines + 1] = co
    coroutine.resume(co)
end

function reactor:Run()
    local read = {}
    for Socket, V in pairs(self._read_sockets) do
        read[#read+1] = Socket
    end
    local write = {}
    for Socket, V in pairs(self._write_sockets) do
        write[#write+1] = Socket
    end

    while true do
        if self._quit then
            hook.Call('ReactorQuit')
            break
        end
        local r, w, e = socket.select(read, write, self._quantum)
        if e == nil then
            -- we actually got something on our sockets
            for Socket, Data in pairs(self._read_sockets) do
                if r[Socket] ~= nil then
                    --Socket:settimeout(3)
                    local Line, Error = Socket:receive('*l')
                    if Error then
                        error('Could not receive line: ' .. Error)
                    end
                    local Callback = Data[1]
                    local Args = Data[2]
                    self:Spawn(Callback, Line, unpack(Args))
                end
            end
            for Socket, Data in pairs(self._write_sockets) do
                if w[Socket] ~= nil then
                    local Callback = Data[1]
                    local Args = Data[2]
                    self:Spawn(Callback, Socket, unpack(Args))
                end
            end
        end
        -- See, if we should wake up any sleepers
        for Coroutine, Timeout in pairs(self._co_sleep) do
            if os.time() > Timeout then
                self._co_sleep[Coroutine] = nil
                coroutine.resume(Coroutine)
            end
        end
        hook.Call('ReactorTick')
        local Time = os.time()
        for TimerName, Data in pairs(self._timers) do
            if Time >= Data.NextTick then
                local Result = Data.Callback()
                if Data.Period ~= nil and Result ~= false then
                    Data.NextTick = Data.NextTick + Data.Period
                else
                    self._timers[TimerName] = nil
                end
            end
        end
    end
end

function reactor:SetTimer(name, tick_at, callback, periodic)
    local Data = {}
    Data.Callback = callback
    if periodic then
        Data.Period = tick_at
    end
    Data.NextTick = os.time() + tick_at
    self._timers[name] = Data
end

function reactor:RemoveTimer(name)
    self._timers[name] = nil
end

function reactor:TCPConnect(host, port, receive_callback, ...)
    local Socket = socket.connect(host, port)
    local Args = {...}
    local SocketStructure = { receive_callback, Args }
    self._read_sockets[Socket] = SocketStructure
    return Socket
end
