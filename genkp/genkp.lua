component = require("component")
files = require("ocmutils.files")

if files.isPlainFile(files.PRKEY_PATH) then
    io.stderr:write("Keypair already exists for this computer.\n")
    return 1
end

local pubkey, prkey = component.data.generateKeyPair()
if not files.writeBinary(files.PUBKEY_PATH, pubkey.serialize()) then
    io.stderr:write("Failed to write public key.\n")
    return 1
end

if not files.writeBinary(files.PRKEY_PATH, prkey.serialize()) then
    io.stderr:write("Failed to write private key.\n")
    return 1
end

print("Keypair successfully generated.")
