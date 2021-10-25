local skynet     = require("skynet")
require "skynet.manager"
local sharetable = require("skynet.sharetable")
local cluster    = require("skynet.cluster")

skynet.start(function()
  local mode = skynet.getenv "mode"
  if mode == "G" then
    cluster.open(mode)
    sharetable.loadfile(skynet.getenv("daobiao"))

    skynet.newservice("debug_console", 7001)
    local loginserver = cluster.proxy("L@logind")
    local gate        = skynet.newservice("gated", loginserver)
    cluster.register("sample", gate)
    skynet.call(gate, "lua", "open",
                { port       = 8888, maxclient  = 64, servername = "sample" })

  elseif mode == "L" then
    skynet.newservice("debug_console", 7002)

    local loginserver = skynet.newservice("logind")
    cluster.register("logind", loginserver)
    cluster.open(mode)

    local db          = skynet.newservice("dbproxymongo")
    skynet.name(".accdb", db)
    skynet.call(db, "lua", "start", {
      host     = "127.0.0.1",
      port     = 27017,
      username = "acc",
      password = "wouinibaba",
      authdb   = "account",
    })
  end
end)
