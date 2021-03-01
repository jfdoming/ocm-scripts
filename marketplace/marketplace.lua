local component = require("component")
local event = require("event")
local Trie = require("trie")

local DATABASE_ENTRY = 1
local MAX_ITEM_TYPES_AT_ONCE = 1
local INTERFACE_SLOT = 1

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
local function _firstFreeSlot(tr, side)
    for i = 1, tr.getInventorySize(side) do
        local item = tr.getStackInSlot(side, i)
        if item == nil then
            return i
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

local function _mergeTypes(tr, side)
    for i=1, tr.getInventorySize(side) - 1 do
        for j=2, tr.getInventorySize(side) do
            local stackA, stackB = tr.getStackInSlot(side, i), tr.getStackInSlot(side, j)

            if stackA and stackB and tr.compareStacks(side, i, j, true) then
                if stackA.size ~= stackA.maxSize and stackB.size ~= stackB.maxSize then
                    local count = math.min(stackA.maxSize - stackA.size, stackB.size)
                    tr.transferItem(side, side, count, j, i)
                end
            end
        end
    end
end

-- Logic component.
function marketplace.logic.getSourceSide(side)
    return _marketplace.logic.sourceSide
end
function marketplace.logic.setSourceSide(side)
    _marketplace.logic.sourceSide = side
end
function marketplace.logic.getSinkSide(side)
    return _marketplace.logic.sinkSide
end
function marketplace.logic.setSinkSide(side)
    _marketplace.logic.sinkSide = side
end

function marketplace.logic.getInterface(c)
    return _marketplace.logic.interfaceComponent
end
function marketplace.logic.setInterface(c)
    _marketplace.logic.interfaceComponent = c
end
function marketplace.logic.getTransposer(c)
    return _marketplace.logic.transposerComponent
end
function marketplace.logic.setTransposer(c)
    _marketplace.logic.transposerComponent = c
end
function marketplace.logic.getDatabase(c)
    return _marketplace.logic.databaseComponent
end
function marketplace.logic.setDatabase(c)
    _marketplace.logic.databaseComponent = c
end

function marketplace.transferByFilter(filter, count)
    if _marketplace.logic.sourceSide == nil or _marketplace.logic.sinkSide == nil then
        return 0, "Logic not configured."
    end

    if count == nil then
        count = 1
    end

    -- Blocklist specific fields.
    filter.size = nil

    local countTransferred, err = _protectedSection("logic", function()
        _marketplace.logic.databaseComponent.clear(DATABASE_ENTRY)
        _marketplace.logic.interfaceComponent.store(
            filter,
            _marketplace.logic.databaseComponent.address,
            DATABASE_ENTRY,
            MAX_ITEM_TYPES_AT_ONCE
        )

        if _marketplace.logic.databaseComponent.get(DATABASE_ENTRY) == nil then
            return 0, "Item not found."
        end

        _marketplace.logic.interfaceComponent.setInterfaceConfiguration(
            INTERFACE_SLOT,
            _marketplace.logic.databaseComponent.address,
            DATABASE_ENTRY,
            count
        )

        -- Allow a bit of time for the items to transfer.
        os.sleep(0.5)

        -- Find an appropriate output slot.
        local outputSlot = _firstFreeSlot(
            _marketplace.logic.transposerComponent,
            _marketplace.logic.sinkSide
        )
        if not outputSlot then
            return 0, "No free slot in export chest."
        end

        -- Use the transposer to make sure we export EXACTLY the correct number of items.
        return _marketplace.logic.transposerComponent.transferItem(
            _marketplace.logic.sourceSide,
            _marketplace.logic.sinkSide,
            count,
            INTERFACE_SLOT,
            outputSlot
        )
    end)
    return countTransferred, err
end

function marketplace.transferByInternalName(name, count)
    return marketplace.transferByFilter({name = name}, count)
end

function marketplace.transferByName(name, count)
    local result, err = marketplace.search.invoke(name)
    if result == nil then
        return 0, err
    end

    local _, stack = next(result)
    if stack == nil then
        return 0, "Item not found."
    end

    local internalName = stack.name
    if stack ~= nil then
        return marketplace.transferByFilter(stack, count)
    end
    return 0, "Item not found."
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
        return nil, "Search string is required."
    end

    if _marketplace.search.instance == nil then
        return nil, "Search not enabled."
    end

    local searchResult, err = _protectedSection("search", function()
        return _marketplace.search.instance:search(name)
    end)
    return searchResult, err
end


return marketplace
