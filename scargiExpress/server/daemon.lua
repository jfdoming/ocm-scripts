-- Note: this should be run as an RC script!

local Router = require("net.router")
local Server = require("net.server")

local server = nil

function start()
    if server ~= nil and server.isRunning() then
        return
    end

    local routePath = args.routePath
    if type(routePath) ~= "string" then
        error("ERROR: invalid configuration. args.routePath is required.")
    end

    local config = {
        router = Router(routePath),
        forwardPort = args.forwardPort or 22,
        replyPort = args.replyPort or 23,
    }
    server = Server(config)
    server:start()
end

function stop()
    server:stop()
    server = nil
end
