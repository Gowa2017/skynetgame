-- LuaFormatter off
SERVICE_NAME = SERVICE_NAME or ...
--- user for logger
SERVICE_DESC = table.concat({ ... })
LOG          = require("go.logger")
CLASS        = require("class")
-- LuaFormatter on

local skynet = require("skynet")
if skynet.getenv "dev" then
  package.path = package.path .. ";3rd/Penlight/lua/?.lua"
end
