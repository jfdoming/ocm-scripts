local component = require("component")
local mk = require("marketplace")
local event = require("event")

mk.search.enable()

function tunnelMessage(tunnel, requestSearch, requestCount)
    local result, err = mk.transferByName(requestSearch, tonumber(requestCount))
    tunnel.send(result, err)
    return result, err
end

function modemMessage(_1, receiver, _2, _3, _4, ...)
    if component.list("tunnel")[receiver] ~= "tunnel" then
        -- Only accept connections from linked cards.
        return
    end

    local tunnel = component.proxy(receiver)
    local status, err, result = xpcall(tunnelMessage, debug.traceback, tunnel, ...)
    if not status then
        io.stderr:write("[daemon] ERROR: " .. err .. "\n")
    end
end

local eventID = event.listen("modem_message", modemMessage)
print("Listening for item requests with event ID " .. eventID .. ".")
