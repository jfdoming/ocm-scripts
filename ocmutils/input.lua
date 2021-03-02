local filesystem = require("filesystem")
local files = require("ocmutils.files")

local input = {}

function input.confirm(prompt, yesAnswer)
    if prompt == nil then
        prompt = "Are you sure you want to continue? "
    end
    if yesAnswer == nil then
        yesAnswer = {"yes", "y"}
    end

    io.write(prompt)
    answer = io.read()

    if answer == nil then
        print()
        return false
    end
    if answer == false then
        return false
    end

    for _, yes in ipairs(yesAnswer) do
        if answer:lower() == yes then
            return true
        end
    end
    return false
end

function input.getFromList(list, listStrings, name, first)
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

function input.getFilesystem()
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

    return input.getFromList(fileEntries, fileLabels, "filesystems", true)
end

function input.getFromPath(path, typeName, filter, first)
    if typeName == nil then
        typeName = "file"
    end
    if typeNamePlural == nil then
        typeNamePlural = typeName .. "s"
    end
    typeName = typeName:sub(1, 1):upper() .. typeName:sub(2)

    fileEntries = filesystem.list(path)
    directories = {}
    directoryLabels = {}
    for file in fileEntries do
        if filter ~= nil and filter(path .. file, file) then
            directories[#directories + 1] = file
            directoryLabels[#directoryLabels + 1] = typeName .. " \"" .. filesystem.name(file) .. "\""
        end
    end

    if #directories == 0 then
        return nil
    end

    return input.getFromList(directories, directoryLabels, typeNamePlural, first)
end

return input
