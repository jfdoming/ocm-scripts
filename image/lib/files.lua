filesystem = require("filesystem")

crypto = require("image.lib.crypto")

local PRKEY_PATH = "/.prkey"
local SIG_SUFFIX = ".sig"

local files = {}

files.isPlainFile = function(path)
    return filesystem.exists(path) and not filesystem.isDirectory(path)
end

files.copy = function(source, dest)
    local copy = assert(loadfile("/bin/cp.lua"))
    copy("-ur", source, dest)
end

files.readBinary = function(path)
    if not files.isPlainFile(path) then
        return nil
    end

    local file = filesystem.open(path, "rb")
    if file == nil then
        file:close()
        return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
end

files.writeBinary = function(path, data)
    if not files.isPlainFile(path) then
        return nil
    end

    local file = filesystem.open(path, "wb")
    if file == nil then
        file:close()
        return nil
    end
    local result = file:write(data)
    file:close()
    return result
end

files.sign = function(path)
    local data = files.readBinary(path)
    if data == nil then
        return false
    end

    local prkey = files.readBinary(PRKEY_PATH)
    if prkey == nil then
        return false
    end

    local sig = crypto.sig(data, key)
    if sig == nil then
        return false
    end

    local sigpath = path .. SIG_SUFFIX
    return files.writeBinary(sigpath)

return files
