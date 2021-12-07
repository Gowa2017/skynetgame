local skynet     = require("skynet")
require "skynet.manager"
local sharetable = require("skynet.sharetable")

skynet.start(function()
  sharetable.loadfile(skynet.getenv("daobiao"))
  skynet.newservice("debug_console", 7001)
  skynet.newservice("agentpool")
  skynet.newservice("world")
  local login   = skynet.newservice("logind")
  local gate    = skynet.newservice("gated", login)
  skynet.call(gate, "lua", "open",
              { port       = 8888, maxclient  = 64, servername = "sample" })
  local db      = skynet.newservice("dbproxymongo")
  skynet.name(".accdb", db)
  skynet.call(db, "lua", "start", {
    host     = "42.192.43.15",
    port     = 27017,
    username = "acc",
    password = "wouinibaba",
    authdb   = "account",
  })
  local message = require("conf.message")
  skynet.register_protocol(message.db)
  local r       = skynet.call(db, "db", "find", "account", { id = 1 })
  local pretty  = require("pl.pretty")
  pretty.dump(r)
end)
