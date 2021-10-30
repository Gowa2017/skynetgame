local skynet = require("skynet")
local maps   = {}

local CMD    = {}
function CMD.created(id, map)
  maps[id] = map
end
function CMD.enter(user)
  return maps[user.map].description, maps[user.map].npcs
end

skynet.start(function()
  skynet.dispatch("lua", function(session, source, cmd, ...)
    local f = assert(CMD[cmd])
    skynet.retpack(f(...))
  end)
end)
