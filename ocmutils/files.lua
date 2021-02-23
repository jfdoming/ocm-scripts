local component = require("component")
local filesystem = require("filesystem")
local os = require("os")

local files = {}

files.PUBKEY_PATH = "/.pubkey"
files.PRKEY_PATH = "/.prkey"
files.BIN_SUFFIX = ".bin"
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
    file:write(data)
    file:close()
    return true
end

files.encrypt = function(path, shkey, iv)
    local data = files.readBinary(path)
    if data == nil then
        return false, "Invalid path."
    end

    if shkey == nil or iv == nil then
        return false, "Invalid key or IV."
    end

    -- Retry a couple of times to try to work around power restrictions.
    local tries = 3
    local encrypted, what = nil, nil
    while tries > 0 do
        tries = tries - 1
        encrypted, what = component.data.encrypt(data, shkey, iv)
        if encrypted ~= nil then break end
        if what ~= "not enough energy" then
            return false, what
        end
        if tries > 0 then os.sleep(1) end
    end
    if encrypted == nil then
        return false, what
    end

    return files.writeBinary(path .. files.BIN_SUFFIX, encrypted)
end

files.sign = function(path, prkey)
    local data = files.readBinary(path)
    if data == nil then
        return false, "Invalid path."
    end

    if prkey == nil then
        prkey = files.readBinary(files.PRKEY_PATH)
        if prkey == nil then
            return false, "Invalid private key."
        end
        prkey = component.data.deserializeKey(prkey, "ec-private")
    end

    -- Retry a couple of times to try to work around power restrictions.
    local tries = 3
    local sig, what = nil, nil
    while tries > 0 do
        tries = tries - 1
        sig, what = component.data.ecdsa(data, prkey)
        if sig ~= nil then break end
        if what ~= "not enough energy" then
            return false, what
        end
        if tries > 0 then os.sleep(1) end
    end
    if sig == nil then
        return false, what
    end

    local sigpath = path .. files.SIG_SUFFIX
    return files.writeBinary(sigpath, sig)
end

files.encryptAndSignAll = function(sourceDir, epubkey, iv)
    if not files.isPlainDirectory(sourceDir) then
        return false, "Invalid source directory."
    end

    if epubkey == nil then
        return false, "No public key."
    end

    local sprkey = files.readBinary(files.PRKEY_PATH)
    if sprkey == nil then
        return false, "Bad private key."
    end
    sprkey = component.data.deserializeKey(sprkey, "ec-private")

    local shkey = component.data.ecdh(sprkey, epubkey)
    if shkey == nil then
        return false, "Bad shared key."
    end

    -- Unfortunately, this AES implementation only takes 128-bit keys.
    -- Choose a substring of the generated key as our shared key.
    shkey = shkey:sub(8, 23)

    if string.sub(sourceDir, -1) ~= "/" then
        sourceDir = sourceDir .. "/"
    end

    local queue = {first = 1, curr = 2}
    queue[1] = sourceDir
    while queue.first < queue.curr do
        curr = queue[queue.first]
        queue.first = queue.first + 1
        for file in filesystem.list(curr) do
            file = curr .. file
            if files.isPlainDirectory(file) then
                queue[queue.curr] = file
                queue.curr = queue.curr + 1
            elseif files.isPlainFile(file) then
                if string.sub(file, -4, -1) == ".lua" then
                    local result, what = files.encrypt(file, shkey, iv)
                    if not result then
                        return result, what
                    end
                    filesystem.remove(file)
                    file = file .. files.BIN_SUFFIX
                end

                local result, what = files.sign(file, sprkey)
                if not result then
                    return result, what
                end
            end
        end
    end

    return true
end


return files
