local net   = require("netproto")
local crypt = require("skynet.crypt")
local state = require "state"

---@param fd integer
---@param msg c2s.login.Handshake
function Handshake(fd, msg)
  local c = state.clients[fd]
  c.ckey = msg.key
  c.secret = crypt.dhsecret(c.ckey, c.skey)
  net.send(fd, "s2c.login.Key", { key = crypt.dhexchange(c.skey) })
end

---@param fd integer
---@param msg c2s.login.Auth
function Auth(fd, msg)
  local c    = state.clients[fd]
  local hash = crypt.hmac64(c.challenge, c.secret)
  if hash ~= msg.hash then error("客户端验证不通过") end
  net.send(fd, "s2c.login.HandshakeOK", { code   = 0, errmsg = "" })
end

---@param fd integer
---@param msg c2s.login.Login
function Login(fd, msg)
  net.send(fd, "s2c.login.LoginOK", { token = "wouinibab" })
end
