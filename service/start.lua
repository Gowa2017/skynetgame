local skynet     = require("skynet")
require "skynet.manager"
local sharetable = require("skynet.sharetable")
local dbproxy    = require("dbproxy")

skynet.start(function()
  -- share pb file
  local sharepb = skynet.getenv("protoFile")
  sharetable.loadfile(sharepb)

  -- debug console
  skynet.newservice("debug_console", 7001)

  -- agent pool
  skynet.newservice("agentpool")

  local login   = skynet.newservice("logind")
  local gate    = skynet.newservice("gated", login)
  skynet.call(gate, "lua", "open",
              { port       = 8888, maxclient  = 64, servername = "sample" })

  local addr    = skynet.newservice("testmysqldb")
  skynet.name(".mysql", addr)
  addr = skynet.newservice("testmongodb")
  skynet.name(".accdb", addr)
end)
