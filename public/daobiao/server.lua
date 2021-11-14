local DIR = "public/daobiao/"
local M   = {}
M.maps = loadfile(DIR .. "Mapss.lua")()
return M
