local component = require("component")
local event = require("event")
local Trie = require("trie")
local account = require("marketplace.account")

local DATABASE_ENTRY = 1
local MAX_ITEM_TYPES_AT_ONCE = 1
local INTERFACE_BASE_SLOT = 1
local INTERFACE_MAX_SLOT = 9

local marketplace = {}
local _marketplace = {}

marketplace.logic = {}
_marketplace.logic = {}
_marketplace.logic.inUse = false
_marketplace.logic.sourceSide = nil
_marketplace.logic.sinkSide = nil
_marketplace.logic.interfaceComponent = component.me_interface
_marketplace.logic.transposerComponent = component.transposer
_marketplace.logic.databaseComponent = component.database

marketplace.search = {}
_marketplace.search = {}
_marketplace.search.instance = nil
_marketplace.search.inUse = false
_marketplace.search.eventID = nil

-- Utility functions.
local function _firstFreeSlot(tr, side, start)
    if start == nil then
        start = 0
    else
        start = start - 1
    end
    local size = tr.getInventorySize(side)
    for i = 0, size - 1 do
        local j = ((i + start) % size) + 1
        local item = tr.getStackInSlot(side, j)
        if item == nil then
            return j
        end
    end
    return nil
end

local function _protectedSection(key, fn, ...)
    while _marketplace[key].inUse == true do
        coroutine.yield()
    end

    _marketplace[key].inUse = true
    local status, result, err = xpcall(fn, debug.traceback, ...)
    _marketplace[key].inUse = false

    if not status then
        err = result
        result = nil
    end

    return result, err
end

-- Logic component.
function marketplace.logic.getSourceSide()
    return _marketplace.logic.sourceSide
end
function marketplace.logic.setSourceSide(side)
    _marketplace.logic.sourceSide = side
end
function marketplace.logic.getSinkSide()
    return _marketplace.logic.sinkSide
end
function marketplace.logic.setSinkSide(side)
    _marketplace.logic.sinkSide = side
end

function marketplace.logic.getInterface()
    return _marketplace.logic.interfaceComponent
end
function marketplace.logic.setInterface(c)
    _marketplace.logic.interfaceComponent = c
end
function marketplace.logic.getTransposer()
    return _marketplace.logic.transposerComponent
end
function marketplace.logic.setTransposer(c)
    _marketplace.logic.transposerComponent = c
end
function marketplace.logic.getDatabase()
    return _marketplace.logic.databaseComponent
end
function marketplace.logic.setDatabase(c)
    _marketplace.logic.databaseComponent = c
end

function marketplace.purchaseByFilter(username, passwordCleartext, filter, count)
    local code, status, data = account.authenticate(username, passwordCleartext)
    if status ~= true then
        return code, 0, data
    end
    local user = data

    -- Treat everything as costing 1 solar for now.
    if not user:canAfford(count) then
        return 422, 0, "Account cannot afford these items!"
    end

    local amountPurchased = marketplace.transferByFilter(filter, count)

    if not user:deduct(amountPurchased) then
        return 422, 0, "Account cannot afford these items!"
    end

    if not user:commit() then
        return 500, 0, "Account failed to update!"
    end

    return amountPurchased
end

function marketplace.transferByFilter(filter, count)
    if _marketplace.logic.sourceSide == nil or _marketplace.logic.sinkSide == nil then
        return 0, "Logic not configured."
    end

    if count == nil then
        count = 1
    end

    if count <= 0 then
        return 0
    end

    -- Blocklist specific fields.
    filter.size = nil
    filter.aspects = nil

    return _protectedSection("logic", function()
        -- Find an appropriate output slot.
        local initialOutputSlot = _firstFreeSlot(
            _marketplace.logic.transposerComponent,
            _marketplace.logic.sinkSide
        )
        if initialOutputSlot == nil then
            return 503, 0, "No space in export chest."
        end

        _marketplace.logic.databaseComponent.clear(DATABASE_ENTRY)
        _marketplace.logic.interfaceComponent.store(
            filter,
            _marketplace.logic.databaseComponent.address,
            DATABASE_ENTRY,
            MAX_ITEM_TYPES_AT_ONCE
        )

        local itemStack = _marketplace.logic.databaseComponent.get(DATABASE_ENTRY)
        if itemStack == nil then
            return 404, 0, "Item not found."
        end

        -- TODO: add support for multiple slots in parallel.
        local inputSlot = INTERFACE_BASE_SLOT

        local transferAmount = math.min(count, itemStack.maxSize)
        _marketplace.logic.interfaceComponent.setInterfaceConfiguration(
            inputSlot,
            _marketplace.logic.databaseComponent.address,
            DATABASE_ENTRY,
            transferAmount
        )

        local totalRemaining = count
        local outputSlot = nil
        local code = 200
        local err = nil
        while totalRemaining > 0 do
            local newTotal = math.max(totalRemaining - itemStack.maxSize, 0)
            transferAmount = totalRemaining - newTotal

            -- Find an appropriate output slot.
            outputSlot = initialOutputSlot or _firstFreeSlot(
                _marketplace.logic.transposerComponent,
                _marketplace.logic.sinkSide,
                outputSlot
            )
            initialOutputSlot = nil
            if outputSlot == nil then
                code = 503
                err = "Not enough space in export chest."
                break
            end

            -- Use the transposer to make sure we export EXACTLY the correct number of items.
            local actualCount = _marketplace.logic.transposerComponent.transferItem(
                _marketplace.logic.sourceSide,
                _marketplace.logic.sinkSide,
                transferAmount,
                inputSlot,
                outputSlot
            )

            if not actualCount or actualCount == 0 then
                code = 503
                err = "No items left to transfer!"
                break
            end

            -- Clean up the input inventory a bit.
            _marketplace.logic.databaseComponent.clear(DATABASE_ENTRY)
            if totalRemaining > 0 and totalRemaining < itemStack.maxSize then
                _marketplace.logic.interfaceComponent.setInterfaceConfiguration(
                    inputSlot,
                    _marketplace.logic.databaseComponent.address,
                    DATABASE_ENTRY,
                    totalRemaining
                )
            end

            totalRemaining = totalRemaining - actualCount
        end

        _marketplace.logic.interfaceComponent.setInterfaceConfiguration(
            inputSlot,
            _marketplace.logic.databaseComponent.address,
            DATABASE_ENTRY,
            1
        )

        return code, (count - totalRemaining), err
    end)
end

function marketplace.transferByInternalName(name, count)
    return marketplace.transferByFilter({name = name}, count)
end

function marketplace.transferByName(name, count)
    local result, err = marketplace.search.invoke(name)
    if result == nil then
        return 404, 0, err
    end

    local bestLabel, bestStack = nil, nil
    for label, stack in pairs(result) do
        if bestStack == nil or label:len() < bestLabel:len() then
            bestLabel, bestStack = label, stack
        end
    end

    if bestStack == nil then
        return 404, 0, "Item not found."
    end
    return marketplace.transferByFilter(bestStack, count)
end


-- Search component.
local function refreshSearch()
    local result, err = _protectedSection("search", function()
        _marketplace.search.instance = Trie()
        for _, stack in ipairs(component.me_interface.getItemsInNetwork()) do
            _marketplace.search.instance:set(stack.label:lower(), stack)
        end
    end)

    if err then
        io.stderr:write("WARNING: refresh failed.\n")
        io.stderr:write(err .. "\n")
    end
end

function marketplace.search.enable()
    if _marketplace.search.eventID ~= nil then
        -- Already scheduled.
        return
    end

    _marketplace.search.eventID = event.timer(1, refreshSearch, math.huge)
end
function marketplace.search.disable()
    if _marketplace.search.eventID == nil then
        -- Already descheduled.
        return
    end

    event.cancel(_marketplace.search.eventID)
    _marketplace.search.eventID = nil
    _marketplace.search.instance = nil
end
function marketplace.search.isEnabled()
    return _marketplace.search.instance ~= nil
end
function marketplace.search.invoke(name)
    if name == nil then
        return 400, nil, "Search string is required."
    end

    if _marketplace.search.instance == nil then
        return 503, nil, "Search not enabled."
    end

    local searchResult, err = _protectedSection("search", function()
        local result = _marketplace.search.instance:search(name:lower())
        if next(result) == nil then
            return nil, "No results."
        end
        return result
    end)
    return 200, searchResult, err
end


return marketplace
