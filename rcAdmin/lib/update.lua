local files = require("ocmutils.files")
local input = require("ocmutils.input")

local RC_SOURCE_PATH = "usr/share/rcAdmin/"
local RC_BASE_PATH = "etc/rc.d/"
local RC_CONFIG_FILE = "etc/rc.cfg"


local function run(arg)
    -- Determine the filesystem/directory to copy from.
    local source = arg[1]
    if source == nil then
        source = input.getFilesystem()
        if source == nil then
            io.stderr:write("Please specify a filesystem to copy from.\n")
            return 1
        end
    end
    if string.sub(source, -1) ~= "/" then
        source = source .. "/"
    end

    -- Determine the file to copy from.
    local sourceFile = arg[2]
    if sourceFile == nil then
        sourceFile = input.getFromPath(source .. RC_SOURCE_PATH, nil, files.isPlainFile)
        if sourceFile == nil then
            io.stderr:write("Please specify a file to copy from.\n")
            return 1
        end
        sourceFile = source .. RC_SOURCE_PATH .. sourceFile
    end

    -- Determine the filesystem/directory to copy to.
    local dest = arg[2]
    if dest == nil then
        dest = input.getFilesystem()
        if dest == nil then
            io.stderr:write("Please specify a filesystem to copy to.\n")
            return 1
        end
    end
    if string.sub(dest, -1) ~= "/" then
        dest = dest .. "/"
    end

    files.copy(sourceFile, dest .. RC_BASE_PATH)
    if source ~= dest then
        files.copy(source .. RC_CONFIG_FILE, dest .. RC_CONFIG_FILE)
    end
    print("Update successful.")

    return 0
end

return run
