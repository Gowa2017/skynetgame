local DIR = "public/daobiao/"
local M   = {}
M.maps = loadfile(DIR .. "maps.lua")()
return M
