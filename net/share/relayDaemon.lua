-- Note: this should be run as an RC script!

local component = require("component")
local event = require("event")
local serialization = require("serialization")

local eventID = nil
local trustProvidedMeta = (args and args.trustProvidedMeta == true) or false
local forwardingHost = args and args.forwardingHost

local FORWARD_PORT = 22
local REPLY_PORT = 23


local function _reply(meta, ...)
    -- Safety check.
    assert(meta and meta.mode == "___unauthenticated___reply")

    if meta.tunnel then
        local comp = component.proxy(meta.author)
        if comp == nil then
            return
        end
        comp.send(serialization.serialize(meta), ...)
    else
        component.modem.send(meta.author, serialization.serialize(meta), ...)
    end
end

local function _forward(author, tunnel, trusted, ...)
    local newMeta = { trusted = trusted, mode = "forward", author = author, tunnel = tunnel }
    component.modem.send(forwardingHost, FORWARD_PORT, serialization.serialize(newMeta), ...)
end

local function _modemMessage(_1, receiver, sender, _3, _4, _5, ...)
    local status, err, result = nil, nil, nil

    if type(_5) == "string" then
        _5 = serialization.unserialize(_5)
    end

    local meta = _5
    if type(meta) ~= "table" then
        meta = {}
    end

    -- The ___unauthenticated___ here is to indicate that the meta should be treated as possibly malicious.
    if meta.mode == "___unauthenticated___reply" and meta.author ~= nil and meta.tunnel ~= nil then
        -- Make no mistake, we don't know for sure who this is!
        meta.trusted = false
        status, err, result = xpcall(_reply, debug.traceback, meta, ...)
    else
        local tunnel = component.list("tunnel")[receiver] == "tunnel"
        local author = sender
        if tunnel then
            author = receiver
        end
        local trusted = (trustProvidedMeta and meta and meta.trusted == true) or false
        status, err, result = xpcall(_forward, debug.traceback, author, tunnel, trusted, ...)
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
