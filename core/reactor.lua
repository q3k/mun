local socket = require('socket')

reactor = {}

function reactor:Initialize(quantum)
    self._read_sockets = {}
    self._write_sockets = {}
    self._quantum = quantum or 0.1
end

function reactor:Run()
    local read = {}
    for Socket, V in pairs(self._read_sockets) do
        read[#read+1] = Socket
    end
    local write = {}
    for Socket, V in pairs(self._write_sockets) do
        read[#read+1] = Socket
    end

    local r, w, e = socket.select(read, write, self._quantum)
    if e == nil then
        -- we actually got something on our sockets
        for Socket, Data in pairs(self._read_sockets) do
            if r[Socket] ~= nil then
                local Callback = Data[1]
                local Args = Data[2]
                Callback(unpack(Args))
                hook.Call('SocketDataReceived', Socket)
            end
        end
        for Socket, Data in pairs(self._write_sockets) do
            if w[Socket] ~= nil then
                local Callback = Data[1]
                local Args = Data[2]
                Callback(unpack(Args))
            end
        end
    end
    hook.Call('ReactorTick')
end
