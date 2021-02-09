filesystem = require("filesystem")

function getFromList(list, listStrings, name, first)
    if #list == 0 then
        return false
    end

    if #list == 1 then
        return list[1]
    end

    print("Available " .. name .. ":")
    print()

    for i, el in ipairs(listStrings) do
        print(i .. ") " .. el)
    end
    print()

    local number = nil
    while true do
        io.write("Select a number from 1 to " .. #list .. ": ")
        number = io.read()
        if number == nil or number == false then
            return nil
        end
        number = tonumber(number)
        if number ~= nil and number >= 1 and number <= #list then
            break
        end
        print("Invalid number.")
    end

    if list[number] == nil then
        return nil
    end

    print()
    return list[number]
end

local DEFAULT_IMAGE_SEARCH_PATH = "/usr/image/images" -- Must end with "/".
local IMAGE_WRITE_PROTECTION_FILE = ".writeprotect"
local IMAGE_POST_INSTALL_FILE = "postInstall.lua"


function run(arg)
    -- Determine the filesystem/directory to write to.
    local chosenFS = arg[1]
    if chosenFS == nil then
        -- No installation path specified, let the user choose.
        mounts = filesystem.mounts()
        files = {}
        fileLabels = {}
        for node, mount in mounts do
            local label = node.getLabel()
            if label == nil then
                label = "Unlabelled filesystem"
            else
                label = "Filesystem \"" .. label .. "\""
            end
            label = label .. " at path \"" .. mount .. "\""
            files[#files + 1] = mount
            fileLabels[#fileLabels + 1] = label
        end

        if #files == 0 then
            io.stderr:write("How are you running on a system with no filesystem?\n")
            return 1
        end

        chosenFS = getFromList(files, fileLabels, "filesystems", true)
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
        files = filesystem.list(DEFAULT_IMAGE_SEARCH_PATH)
        directories = {}
        directoryLabels = {}
        for file in files do
            if filesystem.isDirectory(DEFAULT_IMAGE_SEARCH_PATH .. file) then
                directories[#directories + 1] = file
                directoryLabels[#directoryLabels + 1] = "Image \"" .. filesystem.name(file) .. "\""
            end
        end

        if #directories == 0 then
            io.stderr:write("No images available. Install some?\n")
            return 1
        end

        chosenImage = getFromList(directories, directoryLabels, "images", false)
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

    io.write("Please type \"ok\" to confirm the installation: ")
    answer = io.read()
    if answer == nil or answer == false or string.lower(answer) ~= "ok" then
        if answer == nil then
            print()
        end
        io.stderr:write("Installation aborted.\n")
        return 1
    end
    print()

    ---- Done argument acquisition. ----


    -- Enable write protection.
    print("Enabling write protection...")
    file = io.open(chosenFS .. IMAGE_WRITE_PROTECTION_FILE, "w")
    if file == nil then
        io.stderr:write("Failed to open file, aborting...\n")
        return 1
    end
    file:close()
    print("Write protection enabled.")

    -- Copy over the image files.
    print("Installing image...")
    local copy = assert(loadfile("/bin/cp.lua"))
    copy("-ur", chosenImage, chosenFS)
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
