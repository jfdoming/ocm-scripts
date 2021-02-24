local component = require("component")
local computer = require("computer")
local geolyzer = component.proxy(component.list("geolyzer")())

local data = {}

print("Default Scan")
print(computer.energy())
data = geolyzer.scan(0, 0)
print(computer.energy())

print("--------------")

print("Single-Block Scan")
print(computer.energy())
data = geolyzer.scan(0, 0, 1, 1, 1, 1)
print(computer.energy())