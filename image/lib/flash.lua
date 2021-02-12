local serialization = require("serialization")
local filesystem = require("filesystem")
local component = require("component")
local eeprom = component.eeprom
local data = component.data

local files = require("ocmutils.files")
local input = require("ocmutils.input")


local DEFAULT_IMAGE_SEARCH_PATH = "/usr/share/image/"
local BIOS_FILE = "bios.lua"
local PEERS_TABLE_FILE = "/.peers"
local AES_IV_SIZE = 16


local function run()
    local prod = input.confirm("Is this a production image? ")

    if not input.confirm("Please type \"ok\" to confirm the flash: ", {"ok"}) then
        io.stderr:write("Flash aborted.\n")
        return 1
    end

    local bios = files.readBinary(DEFAULT_IMAGE_SEARCH_PATH .. BIOS_FILE)
    if bios == nil then
        io.stderr:write("Corrupted installation.\n")
        return 1
    end
    local spubkey = files.readBinary(files.PUBKEY_PATH)
    if bios == nil then
        io.stderr:write("Please generate a public key first.\n")
        return 1
    end

    local peersTable = files.readBinary(PEERS_TABLE_FILE)
    if peersTable == nil then
        -- File doesn't exist yet?
        if filesystem.exists(PEERS_TABLE_FILE) then
            io.stderr:write("Failed to read peers table.\n")
            return 1
        end
        peersTable = {}
    else
        peersTable = serialization.unserialize(peersTable)
    end

    local epubkey, eprkey = data.generateKeyPair()
    epubkey = data.encode64(epubkey:serialize())
    eprkey = data.encode64(eprkey:serialize())
    local iv = data.random(AES_IV_SIZE)
    peersTable[epubkey] = iv

    if not files.writeBinary(PEERS_TABLE_FILE, serialization.serialize(peersTable)) then
        io.stderr:write("Failed to write peers table.\n")
        return 1
    end

    -- B64 encoding is not for security (obviously it's no more secure), but
    -- rather just so that the key is in plaintext.
    local addedCode = "-- " .. epubkey .. "\n"
    addedCode = addedCode .. "local spubkey = \"" .. data.encode64(spubkey) .. "\"\n"
    addedCode = addedCode .. "local eprkey = \"" .. eprkey .. "\"\n"
    addedCode = addedCode .. "local iv = \"" .. data.encode64(iv) .. "\"\n"
    bios = addedCode .. bios

    print("Attempting to write " .. bios:len() .. " bytes...")
    local _, err = eeprom.set(bios)
    if err ~= nil then
        io.stderr:write("Error: " .. err .. "\n")
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
