local fn = {}
---Bind fn to an object
---@param f fun(...)
---@param obj any
---@return function
function fn.bind(f, obj, config)
  if not config then
    return function(...)
      return f(obj, ...)
    end
  end
  return function(...)
    return f(obj, config, ...)
  end
end

function fn.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

function fn.loadScript(path)
  local f, err = loadfile(path, "bt")
  assert(f, err)
  return f()
end

---generate a table which represent a type of error
---@param desc string errormessage
function fn.error(desc)
  return setmetatable({}, {
    __tostring = function()
      return desc
    end,
  })
end

return fn
