local skynet    = require("skynet")
require "skynet.manager"
local timer     = require("go.timer")

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

skynet.start(function()
  skynet.register(".agentpool")
  timer.start()
  checker()
  timer.period(10, checker)
  skynet.dispatch("lua", function(session, source, cmd, ...)
    skynet.retpack(CMD[cmd](...))
  end)
end)
