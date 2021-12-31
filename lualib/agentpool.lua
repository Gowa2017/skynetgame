local function pool_service()
  local skynet    = require("skynet")
  require "skynet.manager"
  local timer     = require("go.timer")
  local pool      = {}
  local min       = skynet.getenv("agentPool") or 20
  local uid_agent = {}
  local agent_uid = {}

  local function checker()
    if #pool < min then
      for i = 1, min - #pool do
        pool[#pool + 1] = skynet.newservice("agent")
      end
    end
  end

  local CMD       = {}
  function CMD.get(gate, uid)
    if uid_agent[uid] then
      return uid_agent[uid]
    end
    local a = table.remove(pool)
    uid_agent[uid] = a
    agent_uid[a] = uid
    return a
  end

  function CMD.close(agent)
    local uid = agent_uid[agent]
    agent_uid[agent] = nil
    uid_agent[uid] = nil
  end

  skynet.dispatch("lua", function(_, source, cmd, ...)
    local f = assert(CMD[cmd], string.format("No cmd %s", cmd))
    skynet.retpack(f(source, ...))
  end)
  timer.start()
  checker()
  timer.period(1 * 100, checker)
end

local skynet  = require("skynet")
local service = require "skynet.service"
local function load_service(t, key)
  if key == "address" then
    t.address = service.new("agentpool", pool_service)
    return t.address
  else
    return nil
  end
end

local function report_close(t)
  local addr = rawget(t, "address")
  if addr then
    skynet.send(addr, "lua", "close")
  end
end
local pool    = setmetatable({},
                             { __index = load_service, __gc    = report_close })

function pool.get(uid)
  return skynet.call(pool.address, "lua", "get", uid)
end

return pool
