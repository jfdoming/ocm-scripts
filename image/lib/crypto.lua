data = require("data")

local crypto = {}

crypto.sig = function(data, prkey, sig)
    prkey = data.deserializeKey(prkey, "ec-private")
    return data.ecdsa(data, prkey, sig)
end

return crypto
