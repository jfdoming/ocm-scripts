local mk = require("marketplace")

return {
    ["api/fetchByName"] = {
        trusted = true,
        serializeInput = false,
        serializeOutput = false,
        handler = mk.transferByName,
    },
    ["api/fetchByFilter"] = {
        trusted = true,
        serializeInput = {true, false},
        serializeOutput = false,
        handler = mk.transferByFilter,
    },
    ["api/search"] = {
        trusted = true,
        serializeInput = false,
        handler = mk.search.invoke,
    },
}
