local component = require("component")
local serialization = require("serialization")

---@class Reply
---@field port number
---@field receiver string
---@field sender string
---@field meta table
local class = {}

---@param responseCode number
function class:send(responseCode, ...)
    local isTunnel = component.list("tunnel")[self.receiver] == "tunnel"
    local newMeta = serialization.serialize({
        mode = "___unauthenticated___reply",
        code = responseCode,
        author = self.meta.author,
        tunnel = self.meta.tunnel
    })
    if isTunnel then
        local tunnel = component.proxy(self.receiver)
        if tunnel == nil then
            return
        end
        tunnel.send(newMeta, ...)
    else
        component.modem.send(self.sender, self.port, newMeta, ...)
    end
end
function class:wrap(route, ...)
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

    local responseCode = results[1]
    if responseCode == nil then
        responseCode = 500
    end
    self:send(responseCode, table.unpack(serializedResults))

    return table.unpack(results)
end

---@param port number
---@param receiver string
---@param sender string
---@param meta table
local function _new(_, port, receiver, sender, meta)
    return setmetatable(
        { port = port, receiver = receiver, sender = sender, meta = meta },
        { __index = class }
    )
end

return setmetatable(class, { __call = _new })