local robot  = require("client.robot")
package.cpath = "./skynet/luaclib/?.so"
local socket = require("client.socket")

local r      = robot.new("127.0.0.1", "8001", "127.0.0.1", "8888",
                         { serial = "line" })

local co     = coroutine.create(function()
  r:start()
end)
while true do
  if r.running then
    coroutine.resume(co)
    socket.usleep(1000)
  else
    return
  end
end
