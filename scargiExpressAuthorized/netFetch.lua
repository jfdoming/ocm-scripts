local component = require("component")
local event = require("event")
local serialization = require("serialization")

local arg = {...}

local requestName = arg[1]
local requestCount = arg[2]
local err = nil

if requestName == nil then
    io.stdout:write("What resource would you like? ")
    requestName = io.read()
    if not requestName or requestName == "" then
        return
    end
end

if requestCount == nil then
    io.stdout:write("How much would you like? ")
    requestCount = io.read()
    if not requestCount then
        return
    elseif requestCount == "" then
        requestCount = nil
    end
end

if requestCount ~= nil then
    if tonumber(requestCount) == nil then
        io.stderr:write("Please specify a number of items.\n")
        return
    end
end

-- Since we're connected via linked card, we need to provide the "meta" field manually.
meta = {
    trusted = true,
}

print("Requesting items...")
component.tunnel.send(serialization.serialize(meta), requestName, requestCount)

while true do
    local _1, receiver, _2, _3, _4, result, err = event.pull("modem_message")
    if receiver == component.tunnel.address then
        if err == nil then
            print(result .. " items transferred.")
        else
            io.stderr:write(err .. "\n")
        end
        break
    end
end
