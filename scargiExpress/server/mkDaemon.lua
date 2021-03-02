-- Note: this should be run as an RC script!

local component = require("component")
local mk = require("marketplace")
local event = require("event")
local serialization = require("serialization")

local eventID = nil

local sides = {
    down = 0,
    up = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5,
}

local FORWARD_PORT = 22
local REPLY_PORT = 23


local function _makeReply(receiver, sender, meta)
    return function(...)
        local isTunnel = component.list("tunnel")[receiver] == "tunnel"
        local newMeta = serialization.serialize({
            mode = "reply",
            author = meta.author,
            tunnel = meta.tunnel
        })
        if isTunnel then
            local tunnel = component.proxy(receiver)
            if tunnel == nil then
                return
            end
            tunnel.send(newMeta, ...)
        else
            component.modem.send(sender, REPLY_PORT, newMeta, ...)
        end
    end
end


local function _requestItems(reply, requestSearch, requestCount)
    local result, err = mk.transferByName(requestSearch, tonumber(requestCount))
    reply(result, err)
    return result, err
end

local function _trustedMessage(receiver, sender, meta, ...)
    -- Just one path for now.
    _requestItems(_makeReply(receiver, sender, meta), ...)
end

local function _modemMessage(_1, receiver, sender, _3, _4, meta, ...)
    if type(meta) ~= "string" then
        return
    end

    meta = serialization.unserialize(meta)
    if meta == nil then
        return
    end

    local status, err, result = nil, nil, nil
    if meta.trusted then
        local status, err, result = xpcall(_trustedMessage, debug.traceback, receiver, sender, meta, ...)
    else
        -- Pass for now.
    end
    if not status then
        io.stderr:write("[daemon] ERROR: " .. err .. "\n")
    end
end

function start()
    if args == nil or args.source == nil or args.sink == nil then
        error("ERROR: invalid configuration. Please configure the \"source\" and \"sink\" parameters inside \"/etc/rc.cfg\".")
    end

    local source = sides[args.source]
    local sink = sides[args.sink]
    if source == nil or sink == nil then
        error("ERROR: invalid configuration. \"source\" and \"sink\" should be strings representing sides.")
    end

    if eventID ~= nil then
        -- Already running.
        return
    end

    mk.logic.setSourceSide(source)
    mk.logic.setSinkSide(sink)
    mk.search.enable()

    component.modem.open(FORWARD_PORT)
    eventID = event.listen("modem_message", _modemMessage)
    if eventID == false then
        -- Already running or something went wrong.
        eventID = nil
    else
        print("Listening for item requests with event ID " .. eventID .. ".")
    end
end

function stop()
    if eventID == nil then
        return
    end
    component.modem.close(FORWARD_PORT)
    event.cancel(eventID)
    eventID = nil
end
