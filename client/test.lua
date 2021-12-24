local robot  = require("client.robot")
package.cpath = "./skynet/luaclib/?.so"
local socket = require("client.socket")

local r      = robot.new("127.0.0.1", "8001", "127.0.0.1", "8888")

local co     = coroutine.create(function()
  r:start()
end)
while true do
  coroutine.resume(co)
  socket.usleep(1000)
end
