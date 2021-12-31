local skynet      = require("skynet")
require "skynet.manager"
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

skynet.dispatch("lua", function(_, _, cmd, ...)
  local f = assert(CMD[cmd])
  skynet.retpack(f(...))
end)

skynet.start(function()
  local res = sharetable.query(skynet.getenv "daobiao")
  for i = 1, 3 do
    services[#services + 1] = skynet.newservice("scene", i)
  end
  for _, map in pairs(res.maps) do
    scenes[map.id] = map
    local s = services[balance]
    map2service[map.id] = s
    skynet.call(s, "lua", "created", map.id, map)
    balance = balance + 1
    if balance > #services then
      balance = 1
    end
  end

  skynet.register(".world")
end)
