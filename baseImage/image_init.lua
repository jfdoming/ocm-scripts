local eeprom = component.list("eeprom")()
if eeprom == nil then
    return "No EEPROM!"
end
eeprom = component.proxy(eeprom)

local checksum, what = exec("/.checksum.lua")
if not checksum then
    return what or "Failed to read checksum!"
end

if eeprom.getChecksum() ~= checksum then
    return "Bad checksum!"
end

exec("/boot/components.lua")
exec("/boot/require.lua")

exec("/init.lua")