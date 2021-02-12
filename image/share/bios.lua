local data = component.proxy(component.list("data")())
local fs = component.list("filesystem")
local eeprom = component.proxy(component.list("eeprom")())

local screen = component.list("screen")()
local gpu, w, h
if screen ~= nil then
    gpu = component.proxy(component.list("gpu")())
    gpu.bind(screen)
    gpu.setResolution(gpu.maxResolution())
    w, h = gpu.getResolution()
end

local printy = 1
local function _write(s, c)
    if gpu == nil then return false end
    gpu.setForeground(c)
    if s == nil then s = "nil\n" end
    if s:sub(-1) ~= "\n" then
        s = s .. "\n"
    end

    s = s:gsub("%\t", "        ")
    for l in s:gmatch("(.-)\n") do
        while l ~= "" do
            gpu.set(1, printy, l)
            printy = printy + 1
            l = l:sub(w + 1, -1)
        end
    end
end
function print(s) return _write(s, 0xFFFFFF) end
function printerr(s) return _write(s, 0xFF0000) end
function clear()
    if gpu == nil then return false end
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, w, h, " ")
    printy = 1
end

clear()

computer.getBootAddress = eeprom.getData
computer.setBootAddress = eeprom.setData

local function isPlainFile(f, p)
    return f.exists(p) and not f.isDirectory(p)
end

local function sig(f, path)
    path = path .. ".sig"
    if not isPlainFile(f, path) then return nil end
    local handle = f.open(path)
    local sig = f.read(handle, math.huge)
    f.close(handle)
    return sig
end


function exec(path)
    path = path .. ".bin"
    local f = component.proxy(computer.getBootAddress())
    local sg = sig(f, path)
    if sg == nil then
        print("Skipping due to missing signature.")
        return false
    end

    local handle = f.open(path)
    local code = ""
    repeat
        local chunk = f.read(handle, math.huge)
        code = code .. (chunk or "")
    until not chunk
    f.close(handle)

    if not data.ecdsa(code, spubkey, sg) then
        print("Skipping due to bad signature.")
        return false
    end

    code = data.decrypt(code, shkey, iv)

    local result, what = load(code)
    if result == nil then
        print("Skipping due to invalid code.")
        return false
    end
    return xpcall(result, debug.traceback)
end

local function boot(f)
    computer.setBootAddress(f)
    computer.beep(440, 0.5)
    clear()
    result, what = exec("/image_init.lua")
    if result == false then return false end
    if result == nil then
        print("Skipping image due to invalid code.")
        return false
    end
    local result, err = xpcall(result, debug.traceback)
    if err == nil then
        printerr("Error: Do not return from an image entrypoint!")
    else
        printerr("Image crashed! Details:")
        printerr(err)
        if gpu == nil then
            error(err)
        end
    end
    return true
end

if spubkey ~= nil and eprkey ~= nil and iv ~= nil then
    spubkey = data.deserializeKey(data.decode64(spubkey), "ec-public")
    eprkey = data.deserializeKey(data.decode64(eprkey), "ec-private")
    iv = data.decode64(iv)
    local shkey = data.ecdh(eprkey, spubkey)
    eprkey = nil
end

if shkey == nil then
    printerr("Invalid keypair.")
else
    local found = false
    for f, _ in pairs(fs) do
        if isPlainFile(f, "/image_init.lua.bin") then
            print("Located image to load.")
            if boot(f) then found = true end
            break
        end
    end
    if not found then
        print("No valid images found.")
    end
end

while true do coroutine.yield() end
