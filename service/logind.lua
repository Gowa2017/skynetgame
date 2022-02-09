local login       = require "snax.loginserver"
local crypt       = require "skynet.crypt"
local skynet      = require "skynet"
local dbproxy     = require("dbproxy")
local LOG         = require("go.logger")

local server      = {
  host       = "127.0.0.1",
  port       = 8001,
  multilogin = false, -- disallow multilogin
  name       = "login_master",
  instance   = 1,
}

skynet.register_protocol {
  id     = 101,
  name   = "db",
  pack   = skynet.pack,
  unpack = skynet.unpack,
}

local accdb       = dbproxy.wrap(".db")
local server_list = {}
local user_online = {}
local user_login  = {}
local autoreg     = skynet.getenv "autoreg"

function server.auth_handler(token)
  -- the token is base64(user)@base64(server):base64(password)
  local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
  user = crypt.base64decode(user)
  server = crypt.base64decode(server)
  password = crypt.base64decode(password)
  local ok, res                = accdb:findOne("account", { username = user })
  if not ok then
    if not autoreg then
      error("User does not exists")
    end

    ok, res = accdb:insert("account", { username = user, password = password })
    if not ok then
      error("User does not exists")
    end

    LOG.info("Auto register :%s, %s", user, password)
    ok, res = accdb:findOne("account", { username = user })
  end

  assert(password == res.password, "Password mismath")
  return server, user
end

function server.login_handler(server, uid, secret)
  LOG.info("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret))
  local gameserver = assert(server_list[server], "Unknown server")
  -- only one can login, because disallow multilogin
  local last       = user_online[uid]
  if last then
    skynet.call(last.address, "lua", "kick", uid, last.subid)
  end

  if user_online[uid] then
    error(string.format("user %s is already online", uid))
  end

  local subid      = tostring(skynet.call(gameserver, "lua", "login", uid,
                                          secret))
  user_online[uid] = { address = gameserver, subid   = subid, server  = server }
  return subid
end

local CMD         = {}

function CMD.register_gate(server, address)
  server_list[server] = address
end

function CMD.logout(uid, subid)
  local u = user_online[uid]
  if u then
    LOG.info("%s@%s is logout", uid, u.server)
    user_online[uid] = nil
  end
end

function server.command_handler(command, ...)
  local f = assert(CMD[command])
  return f(...)
end

login(server)
