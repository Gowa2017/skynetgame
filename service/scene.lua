local service = require("go.service")
local CMD     = {}

local maps    = {}

function CMD.created(id, map)
  maps[id] = map
end
function CMD.enter(user)
  return maps[user.map].name
end

service.setMessageCmds("lua", CMD)
service.start()
