local mk = require("marketplace.api")
local account = require("marketplace.account")
local sides = require("sides")

return {
    ["api/createAccount"] = {
        rateLimit = 5,
        rateLimitOnSuccess = function(_, result)
            if result == true then
                return 60
            end
            return 0
        end,
        serializeInput = false,
        serializeOutput = false,
        handler = account.create,
    },
    ["api/fetchByName"] = {
        rateLimit = 10,
        trusted = true,
        serializeInput = false,
        serializeOutput = false,
        handler = mk.transferByName,
    },
    ["api/fetchByFilter"] = {
        rateLimit = 10,
        serializeInput = {false, false, true, false},
        serializeOutput = false,
        handler = mk.purchaseByFilter,
    },
    ["api/fetchByFilterTrusted"] = {
        rateLimit = 3,
        trusted = true,
        serializeInput = {true, false},
        serializeOutput = false,
        handler = mk.transferByFilter,
        initialize = function(args)
            if type(args) ~= "table" or args.source == nil or args.sink == nil then
                error("ERROR: invalid configuration. Please configure the \"source\" and \"sink\" parameters inside \"/etc/rc.cfg\".")
            end

            local source = sides[args.source]
            local sink = sides[args.sink]
            if source == nil or sink == nil then
                error("ERROR: invalid configuration. \"source\" and \"sink\" should be strings representing sides.")
            end

            mk.logic.setSourceSide(source)
            mk.logic.setSinkSide(sink)
            account.initialize("/db/accounts")
        end,
    },
    ["api/search"] = {
        serializeInput = false,
        rateLimit = 3,
        handler = mk.search.invoke,
        initialize = mk.search.enable,
    },
}
