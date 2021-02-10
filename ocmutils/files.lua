filesystem = require("filesystem")

crypto = require("ocmutils.crypto")

local files = {}

files.PUBKEY_PATH = "/.pubkey"
files.PRKEY_PATH = "/.prkey"
files.SIG_SUFFIX = ".sig"

files.isPlainFile = function(path)
    return filesystem.exists(path) and not filesystem.isDirectory(path)
end

files.isPlainDirectory = function(path)
    return filesystem.exists(path) and filesystem.isDirectory(path)
end

files.copy = function(source, dest)
    local copy = assert(loadfile("/bin/cp.lua"))
    copy("-ur", source, dest)
end

files.readBinary = function(path)
    if not files.isPlainFile(path) then
        return nil
    end

    local file = io.open(path, "rb")
    if file == nil then
        return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
end

files.writeBinary = function(path, data)
    if files.isPlainDirectory(path) then
        return nil
    end

    local file = io.open(path, "wb")
    if file == nil then
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

    local prkey = files.readBinary(files.PRKEY_PATH)
    if prkey == nil then
        return false
    end

    local sig = crypto.sig(data, prkey)
    if sig == nil then
        return false
    end

    local sigpath = path .. files.SIG_SUFFIX
    return files.writeBinary(sigpath, sig)
end

return files
