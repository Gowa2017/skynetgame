local skynet   = require("skynet")
local tconcat  = table.concat
local tunpack  = table.unpack
local netproto
local unpack  

local function pbunpack(...)
  return netproto.unpackString(skynet.tostring(...))
end

-- line base
local function lineunpack(msg, sz)
  local str = skynet.tostring(msg, sz)
  local t   = {}
  for s in string.gmatch(str, "[%a%w]+") do
    table.insert(t, s)
  end
  return tunpack(t)
end

if skynet.getenv("proto") == "pb" then
  netproto = require("netproto")
  unpack = pbunpack
else
  unpack = lineunpack
end

return {
  text   = {
    id     = skynet.PTYPE_TEXT,
    name   = "text",
    pack   = function(...)
      local n = select("#", ...)
      if n == 0 then
        return ""
      end
      if n == 1 then
        return tostring(...)
      end
      return tconcat({ ... }, " ")
    end,
    unpack = skynet.tostring,
  },
  lua    = {
    id   = skynet.PTYPE_LUA,
    name = "lua",
    --- skynet do it, we need manualy call skynet.dispatch('lua',..)
  },
  client = { id     = skynet.PTYPE_CLIENT, name   = "client", unpack = unpack },
  logic  = {
    id     = 100,
    name   = "logic",
    pack   = skynet.pack,
    unpack = skynet.unpack,
  },
  db     = {
    id     = 101,
    name   = "db",
    pack   = skynet.pack,
    unpack = skynet.unpack,
  },
  reload = {
    id     = 102,
    name   = "reload",
    pack   = skynet.pack,
    unpack = skynet.unpack,
  },
}
