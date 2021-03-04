-- Note: this should be run as an RC script!

local component = require("component")
local mk = require("marketplace")
local event = require("event")
local serialization = require("serialization")

local routes = require("scargiExpress.api.routes")

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
    local reply = function(...)
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
    local wrap = function(handler, serializeInput, serializeOutput, ...)
        local input = {...}
        if serializeInput ~= false then
            if type(serializeInput) ~= "table" then
                serializeInput = true
            end
            for i, value in ipairs(input) do
                if serializeInput == true or serializeInput[i] then
                    input[i] = serialization.unserialize(value)
                end
            end
        end

        local results = {handler(table.unpack(input))}

        local serializedResults = results
        if serializeOutput ~= false then
            for i, result in ipairs(results) do
                if serializeOutput == nil or serializeOutput == true or serializeOutput[i] == true then
                    serializedResults[i] = serialization.serialize(result)
                end
            end
        end
        reply(table.unpack(serializedResults))

        return table.unpack(results)
    end
    return {
        send = reply,
        wrap = wrap,
    }
end

local function _handleMessage(trusted, reply, path, ...)
    local route = routes[path:gsub("[^a-zA-Z0-9/_-]", "")]
    if route == nil or (not trusted and route.trusted) or type(route.handler) ~= "function" then
        return
    end

    if route.wrap == false then
        route.handler(reply, ...)
    else
        reply.wrap(route.handler, route.serializeInput, route.serializeOutput, ...)
    end
end

local function _modemMessage(_1, receiver, sender, _3, _4, meta, ...)
    if type(meta) ~= "string" then
        return
    end

    meta = serialization.unserialize(meta)
    if meta == nil then
        return
    end

    local reply = _makeReply(receiver, sender, meta)
    local status, err, result = xpcall(_handleMessage, debug.traceback, meta.trusted, reply, ...)
    if not status then
        reply.send(nil, err)
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
