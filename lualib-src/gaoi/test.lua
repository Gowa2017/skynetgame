package.path = package.path .. ";../../3rd/Penlight/lua/?.lua"
local gaoi   = require("gaoi")

---@type GAOI_SPACE
local space  = gaoi.create(20, 20, 4, 4)
-- eid, etype, actype, wegiht, limit, x, y
space:addObject(1, 1, 2, 1, 100, 1.0, 1.0)
space:addObject(2, 2, 2, 1, 100, 1.0, 1.0)
space:addObject(3, 2, 2, 1, 100, 1.0, 1.0)
space:addObject(4, 3, 3, 1, 100, 1.0, 1.0)
space:addObject(5, 3, 3, 1, 100, 1.0, 1.0)
local t      = space:getview(1, 3)

local pretty = require("pl.pretty")
pretty.dump(t)

local mt     = getmetatable(space)

for k, _ in pairs(mt.__index) do print(string.format("function %s() end", k)) end
