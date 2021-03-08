local component = require("component")
local uuid = require("uuid")
local DB = require("db")

local account = {}
local instance = nil
local pepper = nil

local class = {}

function class:canAfford(amount)
    return self._data.balance ~= nil and self._data.balance >= amount
end

function class:deduct(amount)
    if not self:canAfford(amount) then
        return false
    end

    self._data.balance = self._data.balance - amount
    self.touched = true
    assert(self._data.balance >= 0)
    return true
end

function class:deposit(amount)
    self._data.balance = self._data.balance + amount
    self.touched = true
end

function class:commit()
    if not self.touched then
        return false, "No changes to commit."
    end

    if instance:write(self.name, self._data) == nil then
        return false, "Failed to commit changes to user account."
    end

    self.touched = false
    return true
end

function account.initialize(path)
    if instance ~= nil then
        error("ERROR: Already initialized.")
    end

    instance = DB(path)
    pepper = instance.secretKey

    if pepper == nil then
        error("ERROR: Pepper not found.")
    end

    return true
end

local function _newUserObject(username, userData)
    local user = setmetatable({}, { __index = class })
    user.name = username
    user.touched = false
    user._data = userData
    return user
end

function account.authenticate(username, passwordCleartext)
    if not component.isAvailable("data") or not instance then
        return 500, nil, "Cannot authenticate users right now."
    end

    local userData = instance:read(username)
    if userData == nil then
        -- It's best security practice to not tell the client whether the username exists.
        return 401, false, "Invalid credentials."
    end

    local passwordHashed = component.data.sha256(passwordCleartext .. userData.salt .. pepper)
    if passwordHashed ~= userData.passwordHashed then
        return 401, false, "Invalid credentials."
    end

    return 200, true, _newUserObject(username, userData)
end

function account.create(username, passwordCleartext)
    if not component.isAvailable("data") or not instance then
        return 503, nil, "Cannot create user accounts right now."
    end

    if (
        type(username) ~= "string"
        or type(passwordCleartext) ~= "string"
        or username:gsub("[^a-zA-Z0-9_-]", "") ~= username
        or username == ""
        or passwordCleartext:len() < 8
        or instance:exists(username)
    ) then
        return 422, false, "Invalid username-password combination."
    end

    local userData = {}
    userData.salt = uuid.next()
    userData.passwordHashed = component.data.sha256(passwordCleartext .. userData.salt .. pepper)
    userData.balance = 0

    if instance:write(username, userData) == nil then
        return 500, false, "Failed to create user account."
    end
    return 201, true
end

return account
