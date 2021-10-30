local skynet  = require("skynet")
local service = require("go.service")
local net     = require("netproto")
net.init()
local CMD     = {}

function CMD.login(source, uid, sid, secret)
  -- you may use secret to make a encrypted data stream
  skynet.error(string.format("%s is login", uid))
  gate = source
  userid = uid
  subid = sid
  -- you may load user data from database
end

local function logout()
  if gate then skynet.call(gate, "lua", "logout", userid, subid) end
  skynet.exit()
end

function CMD.logout(source)
  -- NOTICE: The logout MAY be reentry
  skynet.error(string.format("%s is logout", userid))
  logout()
end

function CMD.afk(source)
  -- the connection is broken, but the user may back
  skynet.error(string.format("AFK"))
end

local GAME    = {}
function GAME.Enter(data)
  local sid        = skynet.call(".world", "lua", "userScene",
                                 { map = 1, uid = 2 })
  local desc, npcs = skynet.call(sid, "lua", "enter", { map = 1, uid = 2 })
  return
    net.packString("s2c.game.Scene", { desc = desc, map  = 1, npcs = npcs })
end
service.enableMessage("client")
-- service.setMessageCmds("client", { game = GAME })
-- service.setMessageCmds("lua", CMD)
-- service.start()
local client  = { game = GAME }
skynet.start(function()
  skynet.dispatch("client", function(_, _, cmd, ...)
    skynet.ret(GAME.Enter(...))
  end)
  skynet.dispatch("lua", function(session, source, cmd, ...)
    print(cmd)
    skynet.retpack(skynet.packstring(CMD[cmd](...)))
  end)

end)
