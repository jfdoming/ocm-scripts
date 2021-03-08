local computer = require("computer")

local class = {}

---@param author string
---@param path string
---@param seconds number
function class:enableRateLimitForSeconds(author, path, seconds)
    if self.rateLimits[author] == nil then
        self.rateLimits[author] = {}
    end
    local now = computer.uptime()
    local rateLimit = seconds
    self.rateLimits[author][path] = now + rateLimit
end

---@param author string
---@param path string
function class:isRateLimited(author, path)
    if self.rateLimits[author] == nil then
        return false
    end
    local now = computer.uptime()
    local disabledUntil = self.rateLimits[author][path]
    return disabledUntil ~= nil and disabledUntil - now > 0
end

---@param author string
---@param trusted boolean
---@param reply Reply
---@param path string
function class:handle(author, trusted, reply, path, ...)
    path = path:gsub("[^a-zA-Z0-9/_-]", "")
    local route = self.routes[path]
    if route == nil then
        reply.send(404, nil, "Not Found")
        return
    end
    if not trusted and route.trusted then
        reply.send(403, nil, "Forbidden")
        return
    end

    -- Rate limit all APIs with a basic time limit.
    local rateLimit = route.rateLimit or 1
    if self:isRateLimited(author, path) then
        self:enableRateLimitForSeconds(rateLimit)
        reply.send(429, "Too Many Requests")
        return
    end
    self:enableRateLimitForSeconds(rateLimit)

    local result = nil
    if route.wrap == false then
        result = {route.handler(reply, ...)}
    else
        result = {reply.wrap(route, ...)}
    end

    if type(route.rateLimitOnSuccess) == "function" then
        rateLimit = route.rateLimitOnSuccess(table.unpack(result))
        if type(rateLimit) == "number" and rateLimit > 0 then
            self:enableRateLimitForSeconds(rateLimit)
        end
    end
end

local _validators = {
    rateLimit = {"number", "nil"},
    rateLimitOnSuccess = {"function", "nil"},
    serializeInput = {"table", "boolean", "nil"},
    serializeOutput = {"table", "boolean", "nil"},
    trusted = {"boolean", "nil"},
    handler = {"function"},
    initialize = {"function", "nil"},
}

---@param routes table[]
local function _validate(routes)
    for _, route in ipairs(routes) do
        for key, value in pairs(route) do
            local validator = _validators[key]
            if not validator then
                error("Invalid route definition file: extraneous key \"" .. key .. "\".")
            end
            local found = false
            for _, v in pairs(_validators[key]) do
                if type(value) == v then
                    found = true
                    break
                end
            end
            if not found then
                error("Invalid route definition file: bad key type for key \"" .. key .. "\".")
            end
        end
    end
end

---@param routeFilePath string
local function _new(routeFilePath)
    local status, routes = pcall(require, routeFilePath)
    if not status then
        error("Invalid route definition file.")
    end
    _validate(routes)
    return setmetatable({ routes = routes, rateLimits = {} }, { __index = class })
end

return setmetatable(class, { __call = _new })
