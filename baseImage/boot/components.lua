setmetatable(component, {
    __index = function(_, key)
      return component.getPrimary(key)
    end,
    __pairs = function(self)
      local parent = false
      return function(_, key)
        if parent then
          return next(primaries, key)
        else
          local k, v = next(self, key)
          if not k then
            parent = true
            return next(primaries)
          else
            return k, v
          end
        end
      end
    end
  })

function component.getPrimary(componentType)
    if not component.isAvailable(componentType) then return nil end
    return primaries[componentType]
end