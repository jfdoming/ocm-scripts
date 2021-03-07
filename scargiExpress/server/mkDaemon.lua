-- Note: this should be run as an RC script!

local component = require("component")
local event = require("event")
local serialization = require("serialization")

local routePath = args.routePath
if type(routePath) ~= "string" then
    error("ERROR: invalid configuration. args.routePath is required.")
end
local routes = require(routePath)

local eventID = nil

local FORWARD_PORT = args.forwardPort or 22
local REPLY_PORT = args.replyPort or 23


local function _makeReply(receiver, sender, meta)
    local reply = function(responseCode, ...)
        local isTunnel = component.list("tunnel")[receiver] == "tunnel"
        local newMeta = serialization.serialize({
            mode = "___unauthenticated___reply",
            code = responseCode,
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
    local wrap = function(route, ...)
        local input = {...}
        if route.serializeInput ~= false then
            if type(route.serializeInput) ~= "table" then
                route.serializeInput = true
            end
            for i, value in ipairs(input) do
                if route.serializeInput == true or route.serializeInput[i] then
                    input[i] = serialization.unserialize(value)
                end
            end
        end

        local results = {route.handler(table.unpack(input))}

        local serializedResults = results
        if route.serializeOutput ~= false then
            for i, result in ipairs(results) do
                if route.serializeOutput == nil or route.serializeOutput == true or route.serializeOutput[i] == true then
                    serializedResults[i] = serialization.serialize(result)
                end
            end
        end

        local responseCode = 200
        if results[1] == nil and results[2] ~= nil then
            responseCode = 500
        end
        reply(responseCode, table.unpack(serializedResults))

        return table.unpack(results)
    end
    return {
        send = reply,
        wrap = wrap,
    }
end

local function _handleMessage(trusted, reply, path, ...)
    local route = routes[path:gsub("[^a-zA-Z0-9/_-]", "")]
    if route == nil or type(route.handler) ~= "function" then
        reply.send(404, nil, "Not Found")
        return
    end
    if (not trusted and route.trusted) then
        reply.send(403, nil, "Forbidden")
        return
    end

    if route.wrap == false then
        route.handler(reply, ...)
    else
        reply.wrap(route, ...)
    end
end

local function _modemMessage(_1, receiver, sender, _3, _4, meta, ...)
    if type(meta) ~= "string" then
        return
    end

    meta = serialization.unserialize(meta)
    if meta == nil or type(meta) ~= "table" then
        return
    end

    -- Security feature: ignore non-forwarding packets.
    -- It's possible that a non-forwarded packet could have a malicious meta table.
    local reply = _makeReply(receiver, sender, meta)
    if meta.mode ~= "forward" then
        reply.send(403, nil, "This host has been configured to reject all non-forwarded packets.")
        return
    end

    local status, err, result = xpcall(_handleMessage, debug.traceback, meta.trusted, reply, ...)
    if not status then
        reply.send(500, nil, err)
    end
end

function start()
    for _, route in pairs(routes) do
        if type(route.initialize) == "function" then
            route.initialize(args)
        end
    end

    if eventID ~= nil then
        -- Already running.
        return
    end

    component.modem.open(FORWARD_PORT)
    eventID = event.listen("modem_message", _modemMessage)
    if eventID == false then
        -- Already running or something went wrong.
        eventID = nil
    else
        print("Server daemon running with event ID " .. eventID .. ".")
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
