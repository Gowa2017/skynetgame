local skynet = require("skynet")
local redis  = require("skynet.db.redis")
local LOG    = require("go.logger")

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
        local ok, res = pcall(db[cmd], db, ...)
        if not ok then
          LOG.error(res)
          return skynet.retpack(false)
        end
        skynet.retpack(res)
      end
    end)
  end)

end

return M
