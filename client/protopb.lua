local socket    = require("client.socket")
local proto_map = require("public.proto.protomap")
local pb        = require("pb")
local pbio      = require("pb.io")

pb.load(pbio.read("public/proto/proto.pb"))

local M         = {}
--- game server
--- send data with 2byte length header and 4 byte session id tail
---@param id integer socket id
---@param m string binary data
---@param session integer session id
---@param t string messagetype
---@return string  v binary data sended
---@return integer session session id
function M.send_request(id, m, session, t)
  local msg_type =
    assert(proto_map["c2s"][t], string.format("no message %s", t))
  local v        = pb.ecnode(t, m)
  local size     = 2 + #v + 4
  local package  = string.pack(">I2>I2", size, msg_type) .. v ..
                     string.pack(">I4", session)
  socket.send(id, package)
  return v, session
end

---Unpack server's response, whether success or fail.
---Response is a package which with 1 byte result and 4 byte tail at tail.
---@param v string binary, a package
---@return boolean ok success or fail returned by server
---@return string content data
---@return string message type
function M.recv_response(v)
  local size                           = #v - 5
  local msg_type, content, ok, session = string.unpack(
                                           ">I2c" .. tostring(size) .. "B>I4", v)
  local msg                            = pb.decode(
                                           proto_map["s2cbyid"][msg_type],
                                           content)
  return ok ~= 0, msg, session
end

---Unpack message from data
---@param text string binarydata
---@return string packaged data
---@return string last remained data
function M.unpack_package(text)
  local size = #text
  if size < 2 then
    return nil, text
  end
  local s    = text:byte(1) * 256 + text:byte(2)
  if size < s + 2 then
    return nil, text
  end

  return text:sub(3, 2 + s), text:sub(3 + s)
end

---Send data which will be packed with 2byte length header.
---@param fd integer socket id
---@param pack string binary data
function M.send_package(fd, pack)
  local package = string.pack(">s2", pack)
  socket.send(fd, package)
end

return M
