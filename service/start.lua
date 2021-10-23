local skynet  = require("skynet")

local service = require("go.service")

service.start(function()
  skynet.newservice("debug_console", 7001);
  local gate = skynet.newservice("logind")
  skynet.call(gate, "lua", "cmd.start", { port = 8888 })
end)
