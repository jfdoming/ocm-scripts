component = require("component")
eeprom = component.eeprom
data = component.data

files = require("ocmutils.files")
input = require("ocmutils.input")

local DEFAULT_IMAGE_SEARCH_PATH = "/usr/share/image/"
local BIOS_FILE = "bios.lua"

local function run()
    local bios = files.readBinary(DEFAULT_IMAGE_SEARCH_PATH .. BIOS_FILE)
    if bios == nil then
        error("Corrupted installation.")
        return 1
    end
    local pubkey = files.readBinary(files.PUBKEY_PATH)
    if bios == nil then
        error("Please generate a public key first.")
        return 1
    end

    -- B64 encoding is not for security (obviously it's no more secure), but
    -- rather just so that the key is in plaintext.
    local addedCode = "local pubkey = \"" .. data.encode64(pubkey) .. "\"\n"
    bios = addedCode .. bios

    if not input.confirm("Please type \"ok\" to confirm the installation: ", {"ok"}) then
        print("Flash aborted.")
        return 1
    end

    eeprom.set(bios)
    eeprom.makeReadonly(eeprom.getChecksum())
    print("Flash complete.")

    return 0
end

return run
