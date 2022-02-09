function world_service()
  local skynet        = require("skynet")
  local sharetable    = require("skynet.sharetable")
  local area_services = {}
  local users         = {}

  local CMD = {}
  function CMD.enter(source, roomRef, uid)
    users[uid] = { agent = source }
    local area, room = roomRef:match("(.*):(.*)")
    return area_services[area]
  end

  function CMD.finduser(_, uid)

  end

  function CMD.query(_, ref)
    return area_services[ref]
  end

  skynet.start(function()
    local state = sharetable.query(skynet.getenv("loader"))
    for k, _ in pairs(state.Areas) do
      area_services[k] = skynet.newservice("scene", k)
    end
    skynet.dispatch("lua", function(_, source, cmd, ...)
      local f = assert(CMD[cmd], string.format("CMD %s not found", cmd))
      skynet.retpack(f(source, ...))
    end)
  end)
end

local skynet  = require("skynet")
local service = require("skynet.service")
local M       = {}

local function report_close(t)
  local addr = rawget(t, "address")
  if addr then
    skynet.send(addr, "lua", "close")
  end
end

local function load_service(t, key)
  if key == "address" then
    t.address = service.new("world", world_service)
    return t.address
  else
    return nil
  end
end

local world = setmetatable({},
  { __index = load_service, __gc = report_close })

function M.start()
  service.new("world", world_service)
end

---enter world
function M.enter(roomRef, uid)
  return skynet.call(world.address, "lua", "enter", roomRef, uid)
end

function M.query(ref)
  ref = ref:find(":") and ref:sub(1, ref:find(":") - 1) or ref
  return skynet.call(world.address, "lua", "query", ref)
end

function M.finduser(uid)
  return skynet.call(world.address, "lua", "finduser", uid)
end

return M
