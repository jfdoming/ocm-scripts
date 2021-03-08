drone = component.proxy(component.list("drone")())
net = component.proxy(component.list("modem")())
sides = {bottom = 0, top = 1, back = 2, front = 3, right = 4, left = 5}

DRONE_PORT = 384
WAKE_MSG = "drone_wake"
epsilon = 0.005

count = nil
pickup = {}
route = {}

handlers = {
    addNode = function(dx, dy, dz, ...)
        route[#route+1] = {x=dx, y=dy, z=dz}
        return true
    end,
    setCount = function(n, ...)
        count = n
        return true
    end,
    setPickup = function(dx, dy, dz, ...)
        pickup["x"] = dx
        pickup["y"] = dy
        pickup["z"] = dz
        return true
    end
}

function move(dx, dy, dz)
    drone.move(dx, dy, dz)
    while drone.getOffset() > epsilon do end
end

function send(func, ...)
    net.broadcast(DRONE_PORT, "drone", func, ...)
end

function handleSignal(name, r, s, _1, _2, head, func, ...)
    if not name then return nil end
    checkArg(1, name, "string")
    checkArg(6, head, "string")
    checkArg(7, func, "string")
    if name ~= "modem_message" then return end
    if head ~= "drone" then return end

    status, result = xpcall(handlers[func], debug.traceback, ...)
    if not status then
        send("debug", result)
    end

    return result
end

net.open(DRONE_PORT)
net.setWakeMessage(WAKE_MSG)

send("start")

while handleSignal(computer.pullSignal(5)) do end

if not count then
    error("Item count was nil")
end

if not pickup.x or not pickup.y or not pickup.z then
    error("Pickup location was nil")
end

if #route == 0 then
    error("Route is empty")
end

send("updateStatus", "busy")

move(pickup.x, pickup.y, pickup.z)

while not drone.suck(sides.bottom) do
    if drone.count() ~= 0 then break end
end

if drone.count() ~= count then
    error("Received wrong number of items")
end

move(-pickup.x, -pickup.y, -pickup.z)

for i=1,#route do
    move(route[i].x, route[i].y, route[i].z)
end

while not drone.drop(sides.bottom) do
    if drone.count() == 0 then break end
end

for i=#route,1,-1 do
    move(-route[i].x, -route[i].y, -route[i].z)
end

send("updateStatus", "standby")

net.close(DRONE_PORT)
computer.shutdown()