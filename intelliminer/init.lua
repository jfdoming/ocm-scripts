local robot = component.proxy(component.list("robot")())
local inv = component.proxy(component.list("inventory_controller")())
local gen = component.proxy(component.list("generator")())
local chunk = component.proxy(component.list("chunkloader")())
local sides = {bottom = 0, top = 1, back = 2, front = 3, right = 4, left = 5}
local width, height, depth = 16, 16, 8192
local xPos, yPos, zPos = 0, 0, 0
local xDir, zDir = 0, 1
local chestSide = sides.bottom
local chestPlaced = false
local p = 0

local function turnRight()
	robot.turn(true)
	xDir, zDir = zDir, -xDir
end

local function turnLeft()
	robot.turn(false)
	xDir, zDir = -zDir, xDir
end

local function rotate(xd, zd)
	while zDir ~= zd or xDir ~= xd do
		turnLeft()
	end
end

local function firstFreeSlot()
	for i=2,16 do
		if robot.count(i) == 0 then return i end
	end
	return nil
end

local function placeChest()
	if not chestPlaced then
		chestPlaced = true

		while robot.detect(chestSide) do
			robot.swing(chestSide)
		end

		inv.equip()
		robot.use(chestSide)

		p = 0
		while not robot.detect(chestSide) do
			robot.move(chestSide)
			p = p + 1
		end
	end
end

local function breakChest()
	if chestPlaced then
		chestPlaced = false

		robot.select(1)
		inv.equip()
		
		while robot.detect(chestSide) do
			robot.swing(chestSide)
		end

		while p > 0 do
			robot.move(sides.top)
			p = p - 1
		end
	end
end

local function checkState(flags)
	if flags:match("T") ~= nil then
		if robot.durability() and robot.durability() < 0.003 then
			placeChest()
			robot.drop(chestSide, robot.count())
	
			for i=1, inv.getInventorySize(chestSide) do
				local item = inv.getStackInSlot(chestSide, i)
				if item ~= nil and item.label == "Diamond Pickaxe" and item.damage == 0 then
					inv.suckFromSlot(chestSide, i, item.size)
					break
				end
			end
		end
	end

	if flags:match("I") ~= nil then
		if firstFreeSlot() == nil then
			placeChest()

			for i=2, 16 do
				if robot.count(i) > 0 then
					robot.select(i)
					robot.drop(chestSide, robot.count())
				end
			end
		end
	end

	if flags:match("F") ~= nil then
		if gen.count() < 31 then
			local noCoal = true
			for i=2, 16 do
				local item = inv.getStackInInternalSlot(i)
				if item ~= nil and item.label == "Coal" then
					noCoal = false
					robot.select(i)
					gen.insert(math.min(item.size, 64 - gen.count()))
					break
				end
			end
	
			if noCoal then
				placeChest()
	
				for i=1, inv.getInventorySize(chestSide) do
					local item = inv.getStackInSlot(chestSide, i)
					if item ~= nil and item.label == "Coal" then
						robot.select(firstFreeSlot())
						inv.suckFromSlot(chestSide, i, math.min(item.size, 64 - gen.count()))
						gen.insert(robot.count())
						break
					end
				end
			end
	
			robot.select(1)
		end
	end

	breakChest()
end

local function dig(s)
	if robot.detect(s) then
		checkState("TI")
		robot.swing(s)
	end
end

local function generatePath(w, h)
	local path = {}
	local last = math.fmod(math.ceil(h/3), 2) == 0 and {x=0, y=h-2} or {x=w-1, y=h-2}

	local i = 1
	local x, y = 0, 0 
	repeat
		x = math.fmod(math.floor(i/2), 2) ~= 0 and w-1 or 0
		y = 1

		local r = math.floor((i-1)/2)
		for j=1,r do
			y = y + math.min(3, (h-2) - y)
		end

		path[i] = {x=x, y=y}
		i = i + 1
	until x == last.x and y == last.y
	
	return path
end

local function digUpDown()
	dig(sides.top)
	dig(sides.bottom)
end

local function digTowards(x, y)
	while yPos < y do
        if robot.detect(sides.top) then
			checkState("TI")
            robot.swing(sides.top)
        elseif robot.move(sides.top) then
            yPos = yPos + 1
		end
	end
	
	while yPos > y do
        if robot.detect(sides.bottom) then
			checkState("TI")
            robot.swing(sides.bottom)
        elseif robot.move(sides.bottom) then
            yPos = yPos - 1
		end
	end
	
	if xPos > x then
		while xDir ~= -1 do
			turnLeft()
		end
		while xPos > x do
			digUpDown()
            if robot.detect(sides.front) then
				checkState("T")
                robot.swing(sides.front)
            elseif robot.move(sides.front) then
                xPos = xPos - 1
            end
		end
		digUpDown()
	elseif xPos < x then
		while xDir ~= 1 do
			turnRight()
		end
		while xPos < x do
			digUpDown()
			if robot.detect(sides.front) then
				checkState("T")
                robot.swing(sides.front)
            elseif robot.move(sides.front) then
                xPos = xPos + 1
			end
		end
		digUpDown()
	end
end

local function main()
	if not chunk.isActive() then
		chunk.setActive(true)
	end

	checkState("F")

    local path = generatePath(width, height)
    while zPos < depth do
        rotate(0, 1)
		checkState("TI")
		dig(sides.front)
        robot.move(sides.front)
        zPos = zPos + zDir
        
        if math.fmod(zPos,2) ~= 0 then
            for i=1,#path do
				checkState("TIF")
                digTowards(path[i].x, path[i].y)
            end
        else
            for i=#path,1,-1 do
				checkState("TIF")
                digTowards(path[i].x, path[i].y)
            end
        end
    end

	rotate(0, 1)
	chunk.setActive(false)
end

main()