local skynet      = require("skynet")
local service     = require("go.service")
local sharetable  = require("skynet.sharetable")
local services    = {}
local map2service = {}
local scenes      = {}
local balance     = 1
local users       = {}

local CMD         = {}
function CMD.userScene(user)
  local s = map2service[user.map]
  users[user] = true
  return s
end

service.name(".world")
service.setMessageCmds("lua", CMD)
service.start(function()
  local res = sharetable.query(skynet.getenv "daobiao")
  for i = 1, 3 do services[#services + 1] = skynet.newservice("scene") end
  for id, map in pairs(res.maps) do
    scenes[id] = map
    local s = services[balance]
    map2service[id] = s
    skynet.call(s, "lua", "created", id, map)
    balance = balance + 1
    if balance > #services then balance = 1 end
  end
end)