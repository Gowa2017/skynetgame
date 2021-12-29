local skynet     = require("skynet")
require "skynet.manager"
local sharetable = require("skynet.sharetable")
local dbproxy    = require("dbproxy")

skynet.start(function()
  sharetable.loadfile(skynet.getenv("daobiao"))
  skynet.newservice("debug_console", 7001)
  skynet.newservice("agentpool")
  local login    = skynet.newservice("logind")
  local gate     = skynet.newservice("gated", login)
  skynet.call(gate, "lua", "open",
              { port       = 8888, maxclient  = 64, servername = "sample" })

  local my       = skynet.newservice("testmysqldb")
  local mongo    = skynet.newservice("testmongodb")

  local climy    = dbproxy.wrap(my)
  local climongo = dbproxy.wrap(mongo)

  climongo:run("register", "user", "test")
  climy:run("register", "user", "test")

end)
