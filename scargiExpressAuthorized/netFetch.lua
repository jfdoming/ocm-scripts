local component = require("component")
local event = require("event")
local serialization = require("serialization")

local input = require("ocmutils.input")

local arg = {...}

local requestName = arg[1]
local requestCount = arg[2]

if requestName == nil then
    io.stdout:write("What resource would you like? ")
    requestName = io.read()
    if not requestName or requestName == "" then
        return
    end
end

-- Since we're connected via linked card, we need to provide the "meta" field manually.
local meta = {
    trusted = true,
}

local function receiveReply()
    while true do
        local _1, receiver, _2, _3, _4, resultMeta, result, err = event.pull("modem_message")
        if receiver == component.tunnel.address then
            resultMeta = serialization.unserialize(resultMeta)
            return resultMeta.code, result, err
        end
    end
end

print("Searching...")
component.tunnel.send(serialization.serialize(meta), "api/search", requestName)

local responseCode, result, err = receiveReply()
result = result and serialization.unserialize(result)
if type(result) ~= "table" or err ~= nil then
    if err == nil then
        io.stderr:write("Failed to communicate with the server.")
    else
        io.stderr:write(responseCode .. " " .. err .. "\n")
    end
    return
end

local keys = {}
local values = {}
local i = 1
for _, item in pairs(result) do
    local size = item.size
    if math.floor(size) == size then
        size = math.floor(size)
    end
    keys[i] = item.label .. " (" .. size .. ")"
    values[i] = item
    i = i + 1
end
local item = input.getFromList(values, keys, "item types")
if item == nil then
    io.stderr:write("Please specify an item name to fetch.\n")
    return
end

if requestCount == nil then
    if item.size == 1 then
        requestCount = 1
    else
        io.stdout:write("How much would you like? ")
        requestCount = io.read()
        if not requestCount then
            return
        elseif requestCount == "" then
            requestCount = nil
        end
    end
end

if requestCount ~= nil then
    requestCount = tonumber(requestCount)
    if requestCount == nil then
        io.stderr:write("Please specify a number of items.\n")
        return
    end
end

item = serialization.serialize(item)

print("Requesting items...")
component.tunnel.send(serialization.serialize(meta), "api/fetchByFilter", item, requestCount)

responseCode, result, err = receiveReply()
if type(result) == "number" and result > 0 then
    print(result .. " items transferred.")
end
if type(err) == "string" and err ~= nil then
    io.stderr:write(responseCode .. " " .. err .. "\n")
end
