local data = component.proxy(component.list("data")())
local fs = component.list("filesystem")
local eeprom = component.proxy(component.list("eeprom")())
local invoke = component.invoke

computer.getBootAddress = eeprom.getData
computer.setBootAddress = eeprom.setData

local function isRFile(f, p)
    return invoke(f, "exists", p) and not invoke(f, "isDirectory", p)
end

local function pubkey(f)
    if not isRFile(f, "/.pubkey") then
        return nil
    end
    local handle = invoke(f, "open", "/.pubkey")
    local key = invoke(f, "read", handle, 256)
    invoke(f, "close", handle)
    return key
end

local function sig(f)
    if not isRFile(f, "/.sig") then
        return nil
    end
    local handle = invoke(f, "open", "/.sig")
    local sig = invoke(f, "read", handle, 256)
    invoke(f, "close", handle)
    return sig
end


local function boot(f)
    local pk = pubkey(f)
    if pk == nil then
        return
    end
    pk = data.deserializeKey(pk)

    local sg = sig(f)
    if sg == nil then
        return
    end

    computer.setBootAddress(f)
    local handle = invoke(f, "open", "/init.lua")
    local code = ""
    repeat
        local chunk = invoke(f, "read", handle, math.huge)
        code = code .. (chunk or "")
    until not chunk
    invoke(f, "close", handle)

    if not data.ecdsa(code, key, sg) then
        -- Bad signature.
        return
    end

    computer.beep()
    load(code)()
end

for f, _ in pairs(fs) do
    if invoke(f, "exists", "/init.lua") and not invoke(f, "isDirectory", "/init.lua") then
        boot(f)
        break
    end
end
