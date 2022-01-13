-- LuaFormatter off
SERVICE_NAME = SERVICE_NAME or ...
--- user for logger
SERVICE_DESC = table.concat({ ... })
-- LuaFormatter on

local skynet = require("skynet")
if skynet.getenv "dev" then
  package.path = package.path .. ";3rd/Penlight/lua/?.lua"
  dump = require("pl.pretty").dump
end
