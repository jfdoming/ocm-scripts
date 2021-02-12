-- checksum inserted above

local eeprom = component.proxy(component.list("eeprom")())
local filesystem = require("filesystem")

if eeprom.getChecksum() ~= checksum then
    error("Bad checksum!")
    return 1
end

exec("/init.lua")
