local DIR = "public/daobiao/"
local M   = {}
M.maps = loadfile(DIR .. "Scenes.lua")()
return M
