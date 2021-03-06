local skynet        = require("skynet")
local message       = require("conf.message")
local LOG           = require("go.logger")

local net           = require("netproto")
local sharepb       = skynet.getenv("protoFile")
local sharetable    = require("skynet.sharetable")

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
  LOG.info("AFK")
end

local GAME          = {}
function GAME.Enter(data)
  local sid        = skynet.call(".world", "lua", "userScene",
                                 { map = 1001, uid = 2 })
  local desc, npcs = skynet.call(sid, "lua", "enter", { map = 1001, uid = 2 })
  -- return desc
  return net.packString("s2c.game.Scene",
                        { desc = desc, map  = 1001, npcs = npcs })
end

function GAME.Quit(d)
  logout()
  return net.packString("s2c.game.Save", { version = 1 })
end

skynet.register_protocol(message.client)
skynet.dispatch("client", function(_, _, module, cmd, ...)
  local f = assert(GAME[cmd])
  skynet.ret(f(...))
end)
skynet.dispatch("lua", function(session, source, cmd, ...)
  local f = assert(CMD[cmd])
  skynet.retpack(f(source, ...))
end)
skynet.start(function()
  net.init(sharetable.query(sharepb).schema)
end)
