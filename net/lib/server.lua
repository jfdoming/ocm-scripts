local component = require("component")
local event = require("event")
local serialization = require("serialization")

local Reply = require("net.reply")
local Router = require("net.router")

---@class Server
---@field config table
local Server = {}

function Server:_receiveMessage(_1, receiver, sender, _3, _4, meta, ...)
    if type(meta) ~= "string" then
        return
    end

    meta = serialization.unserialize(meta)
    if meta == nil or type(meta) ~= "table" then
        return
    end

    -- Security feature: ignore non-forwarding packets.
    -- It's possible that a non-forwarded packet could have a malicious meta table.
    local reply = Reply(self.config.replyPort, receiver, sender, meta)
    if meta.mode ~= "forward" then
        reply:send(403, nil, "This host has been configured to reject all non-forwarded packets.")
        return
    end

    local status, err, result = xpcall(Router.handle, debug.traceback, self.config.router, meta.author, meta.trusted, reply, ...)
    if not status then
        reply:send(500, nil, err)
    end
end

---@param auxConfig table
function Server:start(auxConfig)
    if self.eventID ~= nil then
        -- Already running.
        return
    end

    for _, route in pairs(self.config.router.routes) do
        if type(route.initialize) == "function" then
            route.initialize(auxConfig)
        end
    end

    component.modem.open(self.config.forwardPort)
    self.eventID = event.listen("modem_message", function(...) self:_receiveMessage(...) end)
    if self.eventID == false then
        -- Already running or something went wrong.
        self.eventID = nil
    else
        print("Server daemon running with event ID " .. self.eventID .. ".")
    end
end

function Server:stop()
    if self.eventID == nil then
        return
    end
    component.modem.close(self.config.forwardPort)
    event.cancel(self.eventID)
    self.eventID = nil
end

function Server:isRunning()
    return self.eventID ~= nil
end

local function _new(_, config)
    return setmetatable({ config = config }, { __index = Server })
end

return setmetatable(Server, { __call = _new })