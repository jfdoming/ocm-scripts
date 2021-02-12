local serialization = require("serialization")
local filesystem = require("filesystem")
local component = require("component")
local eeprom = component.eeprom
local data = component.data

local files = require("ocmutils.files")
local input = require("ocmutils.input")


local DEFAULT_IMAGE_SEARCH_PATH = "/usr/share/image/"
local BIOS_FILE = "bios.lua"
local EEPROM_TABLE_FILE = "/.flashed"
local AES_IV_SIZE = 16


local function run()
    local prod = input.confirm("Is this a production image? ")

    if not input.confirm("Please type \"ok\" to confirm the flash: ", {"ok"}) then
        io.stderr:write("Flash aborted.")
        return 1
    end

    local bios = files.readBinary(DEFAULT_IMAGE_SEARCH_PATH .. BIOS_FILE)
    if bios == nil then
        io.stderr:write("Corrupted installation.")
        return 1
    end
    local spubkey = files.readBinary(files.PUBKEY_PATH)
    if bios == nil then
        io.stderr:write("Please generate a public key first.")
        return 1
    end

    -- B64 encoding is not for security (obviously it's no more secure), but
    -- rather just so that the key is in plaintext.
    local addedCode = "local spubkey = \"" .. data.encode64(spubkey) .. "\"\n"

    local eepromTable = files.readBinary(EEPROM_TABLE_FILE)
    if eepromTable == nil then
        -- File doesn't exist yet?
        if filesystem.exists(EEPROM_TABLE_FILE) then
            io.stderr:write("Failed to read EEPROM table.")
            return 1
        end
        eepromTable = {}
    else
        eepromTable = serialization.unserialize(eepromTable)
    end

    local epubkey, eprkey = data.generateKeyPair()
    local iv = data.random(AES_IV_SIZE)
    local tableEntry = {}
    tableEntry["pubkey"] = data.encode64(epubkey:serialize())
    tableEntry["iv"] = iv
    eepromTable[eeprom.address] = tableEntry

    if not files.writeBinary(EEPROM_TABLE_FILE, serialization.serialize(eepromTable)) then
        io.stderr:write("Failed to write EEPROM table.")
        return 1
    end

    addedCode = addedCode .. "local eprkey = \"" .. data.encode64(eprkey:serialize()) .. "\"\n"
    addedCode = addedCode .. "local iv = \"" .. data.encode64(iv) .. "\"\n"
    bios = addedCode .. bios

    local _, err = eeprom.set(bios)
    if err ~= nil then
        print("Error: " .. err)
        return 1
    end
    if prod then
        eeprom.setLabel("EEPROM (Robot OS)")
        eeprom.makeReadonly(eeprom.getChecksum())
    else
        eeprom.setLabel("WARNING: DEV IMAGE")
    end
    print("Flash complete.")

    return 0
end

return run
