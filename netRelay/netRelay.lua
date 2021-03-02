-- Note: this should be run as an RC script!

local component = require("component")
local event = require("event")
local serialization = require("serialization")

local eventID = nil
local forwardingHost = args and args.forwardingHost

local FORWARD_PORT = 22
local REPLY_PORT = 23


local function _reply(author, tunnel, ...)
    if tunnel then
        local comp = component.proxy(author)
        if comp == nil then
            return
        end
        comp.send(...)
    else
        component.modem.send(author, ...)
    end
end

local function _forward(author, tunnel, meta, ...)
    local newMeta = { trusted = meta and meta.trusted or false, mode = "forward", author = author, tunnel = tunnel }
    component.modem.send(forwardingHost, FORWARD_PORT, serialization.serialize(newMeta), ...)
end

local function _modemMessage(_1, receiver, sender, _3, _4, _5, ...)
    local status, err, result = nil, nil, nil

    if type(_5) == "string" then
        _5 = serialization.unserialize(_5)
    end

    if _5 ~= nil and _5.mode == "reply" and _5.author ~= nil and _5.tunnel ~= nil then
        status, err, result = xpcall(_reply, debug.traceback, _5.author, _5.tunnel, ...)
    else
        local tunnel = component.list("tunnel")[receiver] == "tunnel"
        status, err, result = xpcall(_forward, debug.traceback, tunnel and receiver or sender, tunnel, _5, ...)
    end

    if not status then
        io.stderr:write("[daemon] ERROR: " .. err .. "\n")
    end
end

function start()
    if forwardingHost == nil then
        error("ERROR: invalid configuration. Please configure the \"forwardingHost\" parameter inside \"/etc/rc.cfg\".")
    end

    if eventID ~= nil then
        -- Already running.
        return
    end

    component.modem.open(REPLY_PORT)
    eventID = event.listen("modem_message", _modemMessage)
    if eventID == false then
        -- Already running or something went wrong.
        eventID = nil
    else
        print("Forwarding all requests to port " .. FORWARD_PORT .. ".")
    end
end

function stop()
    if eventID == nil then
        return
    end
    component.modem.close(REPLY_PORT)
    event.cancel(eventID)
    eventID = nil
end
