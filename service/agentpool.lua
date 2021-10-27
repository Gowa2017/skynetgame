local skynet    = require("skynet")
local service   = require("go.service")
local pool      = {}
local min       = skynet.getenv("agentPool") or 10
local uid2agent = {}

local function checker()
  if #pool < min then
    for i = 1, min - #pool do pool[#pool + 1] = skynet.newservice("agent") end
  end
end

local CMD       = {}

function CMD.get(uid)
  if uid2agent[uid] then return uid2agent[uid] end
  local a = table.remove(pool)
  uid2agent[uid] = a
  return a
end

service.name(".agentpool")
service.setMessageCmds("lua", CMD)
service.start(function()
  checker()
  service.timerPeriod(10, checker)
end)
