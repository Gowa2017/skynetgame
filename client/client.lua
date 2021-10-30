local socket    = require "client.socket"
local skynet    = require("skynet")
local crypt     = require "client.crypt"
local tconcat   = table.concat

local pb        = require("pb")
local pbio      = require("pb.io")
local protoFile = "public/proto/proto.pb"
local protoMap  = "public/proto/protomap.lua"

--- load pb file
local ok, n     = pb.load(pbio.read(protoFile))
assert(ok)
--- load pb message id map
local map       = loadfile(protoMap, "bt")()

if _VERSION ~= "Lua 5.4" then error "Use lua 5.4" end

---write data with line break end
local function writeline(fd, text)
  socket.send(fd, text .. "\n")
end

---unpack a line from string
---@param text string
---@return string|nil #a line, or nil when not found a \n
---@return string #remain test
local function unpack_line(text)
  local from = text:find("\n", 1, true)
  if from then return text:sub(1, from - 1), text:sub(from + 1) end
  return nil, text
end

---used to save incomplete data
local last      = ""

---Used to unpack data from a socket
---@param f fun() unpack function
---@param id number socket fd
---@return function # a closure return a message when called
local function unpack_f(f, id)
  ---Try to read message from socket, when remain data can unpack a message,
  ---return it, or read all data from socket, then unpack.
  ---@param fd number
  ---@param last string
  ---@return function
  ---@return any
  local function try_recv(fd, last)
    local result
    result, last = f(last)
    if result then return result, last end
    local r      = socket.recv(fd)
    if not r then return nil, last end
    if r == "" then
      print "Server closed"
      skynet.exit()
    end
    return f(last .. r)
  end

  return function()
    while true do
      local result
      result, last = try_recv(id, last)
      if result then return result end
      socket.usleep(100)
    end
  end
end

local function encode_token(token)
  return string.format("%s@%s:%s", crypt.base64encode(token.user),
                       crypt.base64encode(token.server),
                       crypt.base64encode(token.pass))
end
local function login(token)
  local fd        = assert(socket.connect("127.0.0.1", 8001))
  local readline  = unpack_f(unpack_line, fd)
  local challenge = crypt.base64decode(readline())
  local clientkey = crypt.randomkey()
  writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
  local secret    = crypt.dhsecret(crypt.base64decode(readline()), clientkey)

  print("sceret is ", crypt.hexencode(secret))

  local hmac      = crypt.hmac64(challenge, secret)
  writeline(fd, crypt.base64encode(hmac))
  local etoken    = crypt.desencode(secret, encode_token(token))
  local b         = crypt.base64encode(etoken)
  writeline(fd, crypt.base64encode(etoken))

  local result    = readline()
  print(result)
  local code      = tonumber(string.sub(result, 1, 3))
  assert(code == 200)
  socket.close(fd)
  return result, secret
end

----- connect to game server

---send a message to server
---@param proto string proto name
---@param v table message table
---@param session number session id
---@return string #protobuf encoded data
---@return number #session id
local function send_request(proto, v, session)
  v = string.pack(">I2", map.c2s[proto]) .. pb.encode(proto, v)
  local size    = #v + 4
  local package = string.pack(">I2", size) .. v .. string.pack(">I4", session)
  socket.send(fd, package)
  return v, session
end

---decode mesage from data
---@param v string data from socket
---@return boolean #server return ok or not
---@return table  #message
---@return integer #sessionid
local function recv_response(v)
  local protoId, content, ok, session = string.unpack(
                                          ">I2c" .. tostring(#v - 7) .. "B>I4",
                                          v)
  print("<======", protoId, content, ok, session)

  content = pb.decode(tconcat(map.s2cbyid[protoId], "."), content)
  return ok ~= 0, content, session
end

---unpack package from data, will delete the header length
---@param text string
---@return string #package data
---@return string #remain data
local function unpack_package(text)
  local size = #text
  if size < 2 then return nil, text end
  local s    = text:byte(1) * 256 + text:byte(2)
  if size < s + 2 then return nil, text end

  return text:sub(3, 2 + s), text:sub(3 + s)
end

local function send_package(fd, pack)
  local package = string.pack(">s2", pack)
  socket.send(fd, package)
end

local function game(token, result, secret)
  local subid       = crypt.base64decode(string.sub(result, 5))
  print("login ok, subid=", subid)
  local text        = "echo"
  local index       = 1

  print("connect")
  fd = assert(socket.connect("127.0.0.1", 8888))
  local readpackage = unpack_f(unpack_package, fd)
  last = ""
  local handshake   = string.format("%s@%s#%s:%d",
                                    crypt.base64encode(token.user),
                                    crypt.base64encode(token.server),
                                    crypt.base64encode(subid), index)
  local hmac        = crypt.hmac64(crypt.hashkey(handshake), secret)

  send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

  print(readpackage())
  print("===>",
        send_request("c2s.game.Enter", { msg  = text, time = os.time() }, 0))
  -- don't recv response
  -- print("<===",recv_response(readpackage()))

  print("disconnect")
  socket.close(fd)

  index = index + 1

  print("connect again")
  fd = assert(socket.connect("127.0.0.1", 8888))
  last = ""

  local handshake   = string.format("%s@%s#%s:%d",
                                    crypt.base64encode(token.user),
                                    crypt.base64encode(token.server),
                                    crypt.base64encode(subid), index)
  local hmac        = crypt.hmac64(crypt.hashkey(handshake), secret)

  send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

  print(readpackage())
  print("===>",
        send_request("c2s.game.Enter", { msg  = "fake", time = os.time() }, 0))
  print("===>",
        send_request("c2s.game.Enter", { msg  = "again", time = os.time() }, 1))
  print("<===", recv_response(readpackage()))
  print("<===", recv_response(readpackage()))

  print("disconnect")
  socket.close(fd)

end

local CMD       = {}

function CMD.start(user, password, server)
  local token = { user   = user, pass   = password, server = server }
  local r, s  = login(token)
  game(token, r, s)
end

skynet.start(function()
  skynet.dispatch("lua", function(session, source, cmd, ...)
    CMD[cmd](...)
  end)
end)
