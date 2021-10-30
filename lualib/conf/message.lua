local skynet   = require("skynet")
local netproto = require("netproto")

return {
  lua    = {
    id   = 10,
    name = "lua",
    --- skynet do it, we need manualy call skynet.dispatch('lua',..)
  },
  client = {
    id     = 3,
    name   = "client",
    unpack = function(...)
      return netproto.unpackString(skynet.tostring(...))
    end,
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
