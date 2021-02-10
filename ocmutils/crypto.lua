local crypto = {}

crypto.sig = function(data, prkey, sig)
    prkey = component.data.deserializeKey(prkey, "ec-private")
    return component.data.ecdsa(data, prkey, sig)
end

return crypto
