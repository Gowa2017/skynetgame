package.path = package.path .. ";../../3rd/Penlight/lua/?.lua"
local aoi    = require("aoi")

local space  = aoi.create(10)

space:update(1, "mw", 1, 1, 1)
space:update(2, "wm", 1, 1, 1)
space:update(3, "wm", 2, 2, 5)

local t      = {}

space:message(t)

local pretty = require("pl.pretty")
pretty.dump(t)
