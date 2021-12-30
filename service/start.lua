local skynet     = require("skynet")
require "skynet.manager"
local sharetable = require("skynet.sharetable")

skynet.start(function()
  -- share pb file

  sharetable.loadfile(skynet.getenv("protoFile"))
  sharetable.loadfile(skynet.getenv("daobiao"))

  -- debug console
  skynet.newservice("debug_console", 7001)

  -- agent pool
  skynet.newservice("agentpool")

  skynet.newservice("world")

  local login = skynet.newservice("logind")
  local gate  = skynet.newservice("gated", login)
  skynet.call(gate, "lua", "open",
              { port       = 8888, maxclient  = 64, servername = "sample" })

  local addr  = skynet.newservice("testmysqldb")
  skynet.name(".mysql", addr)
  addr = skynet.newservice("testmongodb")
  skynet.name(".accdb", addr)
end)
