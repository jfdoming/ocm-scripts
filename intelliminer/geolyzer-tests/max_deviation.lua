local component = require("component")
local geolyzer = component.proxy(component.list("geolyzer")())

local data = 0

for i=0, 16 do
    data = data + geolyzer.scan(8, 8, -8, 1, 1, 1)[1]
end

print(data)