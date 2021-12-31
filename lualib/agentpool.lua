local function pool_service()
  local skynet    = require("skynet")
  require "skynet.manager"
  local timer     = require("go.timer")
  local min       = skynet.getenv("agentPool") or 20
  local pool      = {}
  local uid_agent = { n = 0 }
  local agent_uid = { n = 0 }

  local function checker()
    LOG.info("pool size %d, used %d", #pool, uid_agent.n)
    if #pool < min then
      for i = 1, min - #pool do
        pool[#pool + 1] = skynet.newservice("agent")
      end
    end
  end

  local CMD       = {}
  function CMD.get(uid)
    if uid_agent[uid] then
      return uid_agent[uid]
    end
    local a = table.remove(pool)
    uid_agent[uid] = a
    uid_agent.n = uid_agent.n + 1
    agent_uid[a] = uid
    agent_uid.n = agent_uid.n + 1
    return a
  end

  function CMD.quit(uid)
    skynet.error(string.format("%s quited", uid))
    local agent = uid_agent[uid]
    uid_agent[uid] = nil
    agent_uid[agent] = nil
    uid_agent.n = uid_agent.n - 1
    agent_uid.n = agent_uid.n - 1
  end

  skynet.dispatch("lua", function(_, source, cmd, ...)
    local f = assert(CMD[cmd], string.format("No cmd %s", cmd))
    skynet.retpack(f(...))
  end)
  checker()
  timer.start()
  timer.period(100, checker)
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

local pool    = setmetatable({}, { __index = load_service })

function pool.get(uid)
  return skynet.call(pool.address, "lua", "get", uid)
end

function pool.quit(uid)
  return skynet.call(pool.address, "lua", "quit", uid)
end
return pool
