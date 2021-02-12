component = require("component")
filesystem = require("filesystem")

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
    local result = file:write(data)
    file:close()
    return result
end

files.encrypt = function(source, shkey)
    if not files.isPlainFile(source) then
        return false
    end

    if shkey == nil or iv == nil then
        return false
    end

    code = loadfile(source)
    if code == nil then
        return false
    end
    return files.writeBinary(source .. files.BIN_SUFFIX, component.data.encrypt(code, shkey, iv))
end

files.sign = function(path, prkey)
    local data = files.readBinary(path)
    if data == nil then
        return false
    end

    if prkey == nil then
        prkey = files.readBinary(files.PRKEY_PATH)
        if prkey == nil then
            return false
        end
        prkey = component.data.deserializeKey(prkey, "ec-private")
    end

    local sig = component.data.ecdsa(data, prkey)
    if sig == nil then
        return false
    end

    local sigpath = path .. files.SIG_SUFFIX
    return files.writeBinary(sigpath, sig)
end

files.encryptAndSignAll = function(sourceDir, epubkey, iv)
    if not files.isPlainDirectory(sourceDir) then
        return false
    end

    if epubkey == nil then
        return false
    end

    local sprkey = files.readBinary(files.PRKEY_PATH)
    if sprkey == nil then
        return false
    end
    sprkey = component.data.deserializeKey(sprkey, "ec-private")

    local shkey = component.data.ecdh(sprkey, epubkey)
    if shkey == nil then
        return false
    end

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
                    if not files.encrypt(file, shkey, iv) then
                        return false
                    end
                    filesystem.remove(file)
                    file = file .. files.BIN_SUFFIX
                end
                if not files.sign(file, sprkey) then
                    return false
                end
            end
        end
    end

    return true
end


return files
