local skynet = require("skynet")
return {
  lua    = {
    id   = 10,
    name = "lua",
    --- skynet do it
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
