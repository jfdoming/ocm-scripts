local class = {}

local function _createNode() 
    return {
        children = {},
        value = nil
    }
end

function class:set(key, value)
    local current = self.root
    local iterator = key:gmatch"."
    for ch in iterator do
        local child = current.children[ch]
        if child == nil then
            child = _createNode()
            current.children[ch] = child
        end
        current = child
    end
    current.value = value
end

local function _collect(node, key, results, meta)
    if node == nil or meta.max >= 0 and meta.n - meta.off >= meta.max then
        return results
    end
    if node.value ~= nil then
        -- Leaf node.
        if meta.n >= meta.off then
            results[key] = node.value
        end
        meta.n = meta.n + 1
    end
    for ch, child in pairs(node.children) do
        _collect(child, key .. ch, results, meta)
    end

    return results
end
        
local function _get_node(node, key)
    local iterator = key:gmatch(".")
    for ch in iterator do
        local child = node.children[ch]
        if child == nil then
            return nil
        end
        node = node.children[ch]
    end
    return node
end

function class:search(key, maxCount, offset)
    maxCount = maxCount or -1
    offset = offset or 0
    return _collect(_get_node(self.root, key), key, {}, { n = 0, max = maxCount, off = offset })
end

local function _new(_, source)
    local instance = setmetatable({
        root = _createNode()
    },
    {
        __index = class
    })

    if source ~= nil then
        for k, v in pairs(source) do
            instance:set(k, v)
        end
    end

    return instance
end

return setmetatable({}, {
  __call = _new
})
