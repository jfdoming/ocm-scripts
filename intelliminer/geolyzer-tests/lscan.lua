-- Layer-based geoscan
-- Performs scans in discrete 8x8 horizontal layers

local component = require("component")
local computer = require("computer")
local geolyzer = component.proxy(component.list("geolyzer")())

local s = 8
local off = -(s-1)

local data = {}
local energy = computer.energy()

for i=0, 1 do
    for j=0, 1 do
        for y=0, 15 do
            scan = geolyzer.scan(s*j+off, s*i+off, y+off-1, s, s, 1)
            for z=i*s, (i+1)*s-1 do
                for x=j*s, (j+1)*s-1 do
                    data[x + z*(s*2) + y*(s*2)*(s*2) + 1] = scan[x%s + (z%s)*s + 1]
                end
            end
        end
    end
end

print(energy - computer.energy())

--[[
for i, v in pairs(data) do
    io.write(string.format("%.2f", v))
    if i % 16 == 0 then
        io.write("\n")
    else
        io.write("\t")
    end
end
--]]