filesystem = require("filesystem")

crypto = require("ocmutils.crypto")

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

files.compile = function(source)
    if not files.isPlainFile(source) then
        return false
    end
    code = loadfile(source)
    if code == nil then
        return false
    end
    return files.writeBinary(source .. files.BIN_SUFFIX, string.dump(code))
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

files.compileAndSignAll = function(sourceDir)
    if not files.isPlainDirectory(sourceDir) then
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
                    if not files.compile(file) then
                        return false
                    end
                    filesystem.remove(file)
                    file = file .. files.BIN_SUFFIX
                end
                if not files.sign(file) then
                    return false
                end
            end
        end
    end

    return true
end


return files
