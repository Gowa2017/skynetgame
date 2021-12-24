local skynet   = require("skynet")
local netproto = require("netproto")
local tconcat  = table.concat

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
  client = {
    id     = skynet.PTYPE_CLIENT,
    name   = "client",
    unpack = skynet.tostring,
    -- unpack = function(...)
    --   return netproto.unpackString(skynet.tostring(...))
    -- end,
  },
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
