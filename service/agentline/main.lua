local skynet        = require("skynet")
local sharetable    = require("skynet.sharetable")
local CommandType   = require("core.CommandType")

local message       = require("conf.message")
local LOG           = require("go.logger")
local fn            = require("fn")
local netproto      = require("netproto")
local dbproxy       = require("dbproxy")
local Player        = require("core.Player")
local Attribute     = require("core.Attribute")

local gate, area   
local userid, subid
local db            = dbproxy.wrap(".db")
---@type Player
local player       
local state        

---Ctrl messages
local CMD           = {}
function CMD.login(source, uid, sid, secret)
  -- you may use secret to make a encrypted data stream
  gate = source
  userid = uid
  subid = sid
  LOG.info("%s logined", userid)
  -- you may load user data from database
  local ok, res = db:findOne("player", { name = userid })
  if ok then
    player = Player(res)
  else
    LOG.info("No player %s, create", uid)
    player = Player({ name    = userid, account = userid })
    local defaultAtttributes = {
      health    = 100,
      strength  = 20,
      agility   = 20,
      intellect = 20,
      stamina   = 20,
      armor     = 0,
      critical  = 0,
    };
    for attr, value in pairs(defaultAtttributes) do
      local def = state.Attributes[attr]
      player:addAttribute(Attribute(attr, value, nil, def.formula, def.metadata));
    end
    db:insert("player", player:serialize())
  end
  player:hydrate(state)
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

--- Client request command
local COMMAND       = {}

skynet.start(function()
  skynet.register_protocol(message.client)
  state = sharetable.query(skynet.getenv("loader"))
  for cmd, script in pairs(state.Commands) do
    local command = fn.loadScript(script)
    COMMAND[cmd] = command.fn
    for _, alias in ipairs(command.aliases or {}) do
      COMMAND[alias] = command.fn
    end
  end

  skynet.dispatch("client", function(_, _, cmd, ...)
    local parser      = fn.loadScript(
                          "./bundles/bundle-example-lib/lib/CommandParser.lua")
    local ok, command = pcall(parser.parse, COMMAND, cmd, player)
    if not ok then
      return skynet.retpack(false, command)
    end
    if command.type == CommandType.MOVEMENT then
      player:emit("move", ...)
      return skynet.retpack(true)
    end

    local f           = assert(COMMAND[command.command])
    --- the gated service expect we will retuan a string,
    --- so we need a function to convert return value to a string
    --- But, if we use pb, we need a message type field to pack it,
    --- this will depend the logic function to return it, or we must
    --- do the pack in every logic function.
    if skynet.getenv("proto") == "pb" then
      skynet.ret(netproto.pack(f(...)))
    else
      skynet.retpack(f(..., player))
    end
  end)

  skynet.dispatch("lua", function(session, source, cmd, ...)
    local f = assert(CMD[cmd])
    skynet.retpack(f(source, ...))
  end)
end)
