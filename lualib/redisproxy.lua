local skynet = require("skynet")
local redis  = require("skynet.db.redis")

local M      = {}

---Start a redis proxy service
---@param conf redisconfig
---@param watchhandler? fun():nil #watch handler
function M.connect(conf, watchhandler)
  local db   
  local watch
  skynet.start(function()
    db = redis.connect(conf)
    if watchhandler then
      watch = redis.watch(conf)
      skynet.fork(function()
        while true do
          xpcall(watchhandler, debug.traceback, watch:message())
        end
      end)
    end
    skynet.dispatch("lua", function(_, _, cmd, ...)
      if watch[cmd] then
        skynet.retpack(watch[cmd](watch, ...))
      else
        skynet.retpack(db[cmd](db, ...))
      end
    end)
  end)

end

return M
