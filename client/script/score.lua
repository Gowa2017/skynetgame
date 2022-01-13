---@type Robot
return function(robot)
  while true do
    robot:call("score")
    coroutine.yield "SUSPEND"
  end
end
