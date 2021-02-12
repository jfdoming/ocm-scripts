local data = component.proxy(component.list("data")())
local fs = component.list("filesystem")
local eeprom = component.proxy(component.list("eeprom")())
local invoke = component.invoke

local screen = component.list("screen")()
local gpu, w, h = nil, nil, nil
if screen ~= nil then
    gpu = component.proxy(component.list("gpu")())
    gpu.bind(screen)
    gpu.setResolution(gpu.maxResolution())
    w, h = gpu.getResolution()
end

local printy = 1
local function _write(s)
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
function print(s)
    if gpu == nil then
        return false
    end

    gpu.setForeground(0xFFFFFF)
    _write(s)
    return true
end
function printerr(s)
    if gpu == nil then
        return false
    end

    gpu.setForeground(0xFF0000)
    _write(s)
    return true
end
function clear()
    if gpu == nil then
        return false
    end

    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, w, h, " ")
    printy = 1
end

clear()

computer.getBootAddress = eeprom.getData
computer.setBootAddress = eeprom.setData

local function isPlainFile(f, p)
    return invoke(f, "exists", p) and not invoke(f, "isDirectory", p)
end

local function sig(f)
    if not isPlainFile(f, "/init.lua.sig") then
        return nil
    end
    local handle = invoke(f, "open", "/init.lua.sig")
    local sig = invoke(f, "read", handle, math.huge)
    invoke(f, "close", handle)
    return sig
end


local function boot(f)
    local sg = sig(f)
    if sg == nil then
        print("Skipping image due to missing signature.")
        return false
    end

    computer.setBootAddress(f)
    local handle = invoke(f, "open", "/init.lua")
    local code = ""
    repeat
        local chunk = invoke(f, "read", handle, math.huge)
        code = code .. (chunk or "")
    until not chunk
    invoke(f, "close", handle)

    if not data.ecdsa(code, pk, sg) then
        print("Skipping image due to bad signature.")
        return false
    end

    computer.beep(440, 0.5)
    clear()
    result, what = load(code)
    if result == nil then
        print("Skipping image due to invalid code.")
        return false
    end
    result, err = xpcall(result, debug.traceback)
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

if pubkey ~= nil then
    pubkey = data.deserializeKey(data.decode64(pubkey), "ec-public")
end

if pubkey == nil then
    printerr("Invalid public key.")
else
    local found = false
    for f, _ in pairs(fs) do
        if isPlainFile(f, "/init.lua") then
            print("Located image to load.")
            if boot(f) then
                found = true
            end
            break
        end
    end
    if not found then
        print("No valid images found.")
    end
end

while true do coroutine.yield() end
