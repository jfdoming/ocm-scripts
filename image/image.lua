local COMMANDS = {
    ["install"] = "image.impl.install"
}

local commandKeys = {}
for k, _ in pairs(COMMANDS) do
    commandKeys[#commandKeys + 1] = k
end
local COMMAND_LIST = table.concat(commandKeys, ", ")


arg = {...}

if #arg == 0 or arg[1] == "help" or COMMANDS[arg[1]] == nil then
    print("Usage: image [command]")
    print("Where command is one of: " .. COMMAND_LIST)
    return 0
end

local status, command = pcall(require, COMMANDS[arg[1]])
if not status or command == nil then
    io.stderr:write("Failed to run that command!\n")
    return 1
end

--- Skip the command name and run.
table.remove(arg, 1)
command(arg)
