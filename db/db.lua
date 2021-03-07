local serialization = require("serialization")
local filesystem = require("filesystem")
local files = require("ocmutils.files")
local uuid = require("uuid")

local class = {}

function class:read(entryName)
    local data = files.readBinary(filesystem.concat(self.sourceDir, entryName .. ".db"))
    if type(data) ~= "string" then
        return nil
    end
    return serialization.unserialize(data)
end

function class:write(entryName, data)
    data = serialization.serialize(data)
    return files.writeBinary(filesystem.concat(self.sourceDir, entryName .. ".db"), data)
end

function class:exists(entryName)
    return filesystem.exists(filesystem.concat(self.sourceDir, entryName .. ".db"))
end

local function _new(_, source)
    local secretKey = nil
    if filesystem.isDirectory(source) then
        secretKey = files.readBinary(filesystem.concat(source, "secret.key"))
    else
        if source == nil or filesystem.exists(source) then
            return nil, "Invalid database root directory."
        end
        filesystem.makeDirectory(source)
        secretKey = uuid.next()
        if not files.writeBinary(filesystem.concat(source, "secret.key"), secretKey) then
            return nil, "Failed to create secret key."
        end
    end

    return setmetatable(
        {
            sourceDir = source,
            secretKey = secretKey,
        },
        {
            __index = class
        }
    )
end

return setmetatable({}, {
  __call = _new
})
