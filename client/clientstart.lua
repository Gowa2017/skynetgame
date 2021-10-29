local skynet = require("skynet")
require "skynet.manager"
skynet.start(function()
  for i = 1, 1 do
    local a = skynet.newservice("client")
    skynet.send(a, "lua", "start", "test", "good", "sample")
  end
end)
