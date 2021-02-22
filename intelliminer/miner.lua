local component = require("component")
local computer = require("computer")
local robot = component.proxy(component.list("robot")())
local inv = component.proxy(component.list("inventory_controller")())
local gen = component.proxy(component.list("generator")())
local chunk = component.proxy(component.list("chunkloader")())

local sides = {bottom = 0, top = 1, back = 2, front = 3, right = 4, left = 5}

local width, height, depth = 16, 9, 16
local xPos, yPos, zPos = 0, 0, 0
local xDir, zDir = 0, 1
local chestSide = sides.bottom
local checkDura = false

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

-- Places Ender Chest
-- Postcondition: Ender Chest is above robot, Pickaxe is in slot 1
local function placeChest()
	while robot.detect(chestSide) do
		robot.swing(chestSide)
	end
	inv.equip()
	while not robot.use(chestSide) do end
end

-- Breaks Ender Chest
-- Postcondition: Ender chest is in slot 1, Pickaxe is equipped
local function breakChest()
	robot.select(1)
	inv.equip()
	while robot.detect(chestSide) do
		robot.swing(chestSide)
	end
end

-- Gives the index of the first free inv slot
-- Returns nil if there are no free inv slots
local function firstFreeSlot()
	for i=2,16 do
		if robot.count(i) == 0 then
			return i
		end
	end
	return nil
end

-- Check fuel level and refuel if low
local function refuel()
	if gen.count() == 0 then
		local noCoal = true
		for i=2, 16 do
			local item = inv.getStackInInternalSlot(i)
			if item ~= nil and item.label == "Coal" then
				noCoal = false
				robot.select(i)
				gen.insert(math.min(robot.count(), 64 - gen.count()))
				break
			end
		end

		if noCoal then
			placeChest()

			if firstFreeSlot() == nil then
				deposit()
			end

			for i=1, inv.getInventorySize(chestSide) do
				local item = inv.getStackInSlot(chestSide, i)
				if item ~= nil and item.label == "Coal" then
					robot.select(firstFreeSlot())
					inv.suckFromSlot(chestSide, i, math.min(robot.count(), 64 - gen.count()))
					gen.insert(robot.count())
					break
				end
			end
		
			breakChest()
		end

		robot.select(1)
	end
end

-- Deposit inventory into ender chest
local function deposit()
	for i=2, 16 do
		if robot.count(i) > 0 then
			robot.select(i)
			robot.drop(chestSide, robot.count())
		end
	end
end

local function checkTool()
	if robot.durability() < 0.0012 then
		placeChest()

		robot.drop(chestSide, robot.count())

		for i=1, inv.getInventorySize(chestSide) do
			local item = inv.getStackInSlot(chestSide, i)
			if item ~= nil and item.label == "Diamond Pickaxe" and item.damage == 0 then
				inv.suckFromSlot(chestSide, i, item.size)
				break
			end
		end

		breakChest()
	end
end

local function checkInv()
	if firstFreeSlot() == nil then
		placeChest()
		deposit()
		breakChest()
	end
end

-- Generates graph representing digging pattern
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
	checkInv()

	if robot.detect(sides.top) then
		if checkDura then
			checkTool()
		end
		robot.swing(sides.top)
	end
	
	if robot.detect(sides.bottom) then
		if checkDura then
			checkTool()
		end
		robot.swing(sides.bottom)
	end
end

local function digTowards(x, y)
	if robot.durability() < 0.01 then
		checkDura = true
	else
		checkDura = false
	end

	while yPos < y do
        if robot.detect(sides.top) then
			checkInv()
			if checkDura then
				checkTool()
			end
            robot.swing(sides.top)
        elseif robot.move(sides.top) then
            yPos = yPos + 1
		else
			os.sleep(0.5)
		end
	end
	
	while yPos > y do
        if robot.detect(sides.bottom) then
			checkInv()
			if checkDura then
				checkTool()
			end
            robot.swing(sides.bottom)
        elseif robot.move(sides.bottom) then
            yPos = yPos - 1
		else
			os.sleep(0.5)
		end
	end
	
	if xPos > x then
		while xDir ~= -1 do
			turnLeft()
		end
		while xPos > x do
			digUpDown()
            if robot.detect(sides.front) then
				if checkDura then
					checkTool()
				end
                robot.swing(sides.front)
            elseif robot.move(sides.front) then
                xPos = xPos - 1
            else
                os.sleep(0.5)
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
				if checkDura then
					checkTool()
				end
                robot.swing(sides.front)
            elseif robot.move(sides.front) then
                xPos = xPos + 1
            else
                os.sleep(0.5)
            end
		end
		digUpDown()
	end
end

local function main()
	if chunk.isActive() then
		chunk.setActive(true)
	end

	refuel()

    local path = generatePath(width, height)
    while zPos < depth do
		if computer.energy() / computer.maxEnergy() < 0.1 then
			refuel()
		end

        rotate(0, 1)
        if robot.detect(sides.front) then
			if checkDura then
				checkTool()
			end
            robot.swing(sides.front)
        end
        robot.move(sides.front)
        zPos = zPos + zDir
        
        if math.fmod(zPos,2) ~= 0 then
            for i=1,#path do
                digTowards(path[i].x, path[i].y)
            end
        else
            for i=#path,1,-1 do
                digTowards(path[i].x, path[i].y)
            end
        end
    end

	rotate(0, 1)
	chunk.setActive(false)
end

main()