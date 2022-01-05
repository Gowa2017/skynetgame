local skynet        = require("skynet")
local message       = require("conf.message")
local LOG           = require("go.logger")

local gate         
local userid, subid
local CMD           = {}

function CMD.login(source, uid, sid, secret)
  -- you may use secret to make a encrypted data stream
  gate = source
  userid = uid
  subid = sid
  LOG.info("%s logined", userid)
  -- you may load user data from database
end

local function logout()
  if gate then
    skynet.call(gate, "lua", "logout", userid, subid)
  end
  skynet.exit()
end

function CMD.logout(source)
  -- NOTICE: The logout MAY be reentry
  LOG.info("%s is logout", userid)
  logout()
end

function CMD.afk(source)
  -- the connection is broken, but the user may back
  LOG.info("%s AFK", userid)
end

local GAME          = {}
function GAME.enter(mid)
  mid = tonumber(mid)
  local sid        = skynet.call(".world", "lua", "userScene",
                                 { map = mid, uid = userid })
  local desc, npcs = skynet.call(sid, "lua", "enter",
                                 { map = mid, uid = userid })
  return desc

end

function GAME.quit(d)
  logout()
  return "logouted"
end

skynet.start(function()
  skynet.register_protocol(message.client)

  skynet.dispatch("client", function(_, _, cmd, ...)
    local f = assert(GAME[cmd])
    skynet.ret(f(...))
  end)

  skynet.dispatch("lua", function(session, source, cmd, ...)
    local f = assert(CMD[cmd])
    skynet.retpack(f(source, ...))
  end)
end)
