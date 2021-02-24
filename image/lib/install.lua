local component = require("component")
local filesystem = require("filesystem")
local serialization = require("serialization")

local files = require("ocmutils.files")
local input = require("ocmutils.input")

local DEFAULT_IMAGE_SEARCH_PATH = "/usr/share/image/" -- Must end with "/".
local IMAGE_WRITE_PROTECTION_FILE = ".writeprotect"
local IMAGE_CHECKSUM_FILE = ".checksum.lua"
local IMAGE_BASE_FILE = "baseImage/"
local IMAGE_BASE_PATH = "/usr/share/image/" .. IMAGE_BASE_FILE .. "." -- Must end with "/."
local IMAGE_POST_INSTALL_FILE = "postInstall.lua"
local PEERS_TABLE_FILE = "/.peers"


local function run(arg)
    -- Determine the filesystem/directory to write to.
    local chosenFS = arg[1]
    if chosenFS == nil then
        -- No installation path specified, let the user choose.
        mounts = filesystem.mounts()
        fileEntries = {}
        fileLabels = {}
        for node, mount in mounts do
            local label = node.getLabel()
            if label == nil then
                label = "Unlabelled filesystem"
            else
                label = "Filesystem \"" .. label .. "\""
            end
            label = label .. " at path \"" .. mount .. "\""
            fileEntries[#fileEntries + 1] = mount
            fileLabels[#fileLabels + 1] = label
        end

        if #fileEntries == 0 then
            io.stderr:write("How are you running on a system with no filesystem?\n")
            return 1
        end

        chosenFS = input.getFromList(fileEntries, fileLabels, "filesystems", true)
        if chosenFS == nil then
            io.stderr:write("Please specify a filesystem to install to.\n")
            return 1
        end
    end

    -- Format the filesystem path.
    if string.sub(chosenFS, -1) ~= "/" then
        chosenFS = chosenFS .. "/"
    end

    -- Check for write protection.
    if filesystem.exists(chosenFS .. IMAGE_WRITE_PROTECTION_FILE) then
        io.stderr:write("Image at destination has write protection enabled, aborting...\n")
        return 1
    end

    -- Determine the image to use.
    local chosenImage = arg[2]
    if chosenImage == nil then
        fileEntries = filesystem.list(DEFAULT_IMAGE_SEARCH_PATH)
        directories = {}
        directoryLabels = {}
        for file in fileEntries do
            if filesystem.isDirectory(DEFAULT_IMAGE_SEARCH_PATH .. file) and file ~= IMAGE_BASE_FILE then
                directories[#directories + 1] = file
                directoryLabels[#directoryLabels + 1] = "Image \"" .. filesystem.name(file) .. "\""
            end
        end

        if #directories == 0 then
            io.stderr:write("No images available. You can download images from oppm.\n")
            return 1
        end

        chosenImage = input.getFromList(directories, directoryLabels, "images", false)
        if chosenImage == nil then
            io.stderr:write("Please specify an image directory to install.\n")
            return 1
        end
        chosenImage = DEFAULT_IMAGE_SEARCH_PATH .. chosenImage
    end
    if not filesystem.isDirectory(chosenImage) then
        io.stderr:write("Please specify the path to an image directory.\n")
        return 1
    end

    -- Format the image path.
    if string.sub(chosenImage, -1) ~= "/" then
        chosenImage = chosenImage .. "/"
    end
    chosenImage = chosenImage .. "."

    print("Using destination " .. chosenFS)
    print("Using image from " .. chosenImage)
    print()

    if not input.confirm("Please type \"ok\" to confirm the installation: ", {"ok"}) then
        io.stderr:write("Installation aborted.\n")
        return 1
    end
    print()

    ---- Done argument acquisition. ----


    -- Determine peer pubkey.
    local peerTable = files.readBinary(PEERS_TABLE_FILE)
    if peerTable == nil then
        io.stderr:write("Failed to read peer table.\n")
        return 1
    else
        peerTable = serialization.unserialize(peerTable)
    end
    if component.list("eeprom")() == nil then
        io.stderr:write("No EEPROM present. Insert an EEPROM you want to bind this image to and try again.\n")
        return 1
    end
    local eepromData = component.eeprom.get()
    local epubkey = eepromData:sub(4, eepromData:find("\n") - 1)
    if epubkey == nil or epubkey == "" then
        if component.eeprom.getLabel():lower():find("lua") == nil then
            io.stderr:write("EEPROM metadata corrupted.")
        else
            io.stderr:write("EEPROM metadata corrupted. Perhaps you left in the wrong EEPROM?")
        end
        return 1
    end

    local iv = peerTable[epubkey]
    if iv == nil then
        if component.eeprom.getLabel():lower():find("lua") == nil then
            io.stderr:write("EEPROM metadata corrupted.")
        else
            io.stderr:write("EEPROM metadata corrupted. Perhaps you left in the wrong EEPROM?")
        end
        return 1
    end

    epubkey = component.data.decode64(epubkey)
    epubkey = component.data.deserializeKey(epubkey, "ec-public")
    iv = component.data.decode64(iv)

    -- Enable write protection.
    print("Enabling write protection...")
    file = io.open(chosenFS .. IMAGE_WRITE_PROTECTION_FILE, "w")
    if file == nil then
        io.stderr:write("Failed to open file, aborting...\n")
        return 1
    end
    file:close()
    print("Write protection enabled.")

    -- Save the checksum.
    print("Saving checksum...")
    file = io.open(chosenFS .. IMAGE_CHECKSUM_FILE, "w")
    if file == nil then
        io.stderr:write("Failed to open file, aborting...\n")
        return 1
    end
    file:write("return \"" .. component.eeprom.getChecksum() .. "\"\n")
    file:close()
    print("Checksum saved.")

    -- Copy over the image files.
    print("Installing image...")
    files.copy(chosenImage, chosenFS)
    files.copy(IMAGE_BASE_PATH, chosenFS)
    local result, what = files.encryptAndSignAll(chosenFS, epubkey, iv)
    if not result then
        io.stderr:write("Error: Failed to sign some files in the image. Your image may not boot correctly.\n")
        if what then
            io.stderr:write("Message: " .. what .. "\n")
        end
        print(result, what)
        return 1
    end
    print("Image installed.")

    if filesystem.exists(chosenFS .. IMAGE_POST_INSTALL_FILE) then
        local postInstall = loadfile(chosenFS .. IMAGE_POST_INSTALL_FILE)
        if postInstall ~= nil then
            print("Running post-installation script...")
            postInstall(chosenFS)
        end
        filesystem.remove(chosenFS .. IMAGE_POST_INSTALL_FILE)
    end

    return 0
end

return run
