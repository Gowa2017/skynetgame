local skynet = require("skynet")
local LOG    = require("go.logger")

local maps   = {}

local CMD    = {}
function CMD.created(id, map)
  maps[id] = map
  LOG.info("[%d] %s created", id, map.name)
end
function CMD.enter(user)
  return maps[user.map].desc, maps[user.map].npcs
end

skynet.start(function()
  skynet.dispatch("lua", function(session, source, cmd, ...)
    local f = assert(CMD[cmd])
    skynet.retpack(f(...))
  end)
end)
