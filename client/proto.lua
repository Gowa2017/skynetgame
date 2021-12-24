package.cpath = "./skynet/luaclib/?.so"
local socket = require("client.socket")

local M      = {}
local last   = ""

local function writeline(fd, text)
  socket.send(fd, text .. "\n")
end
local function unpack_line(text)
  local from = text:find("\n", 1, true)
  if from then
    return text:sub(1, from - 1), text:sub(from + 1)
  end
  return nil, text
end

local function unpack_f(f, id)
  local function try_recv(fd, last)
    local result
    result, last = f(last)
    if result then
      return result, last
    end
    local r      = socket.recv(fd)
    if not r then
      return nil, last
    end
    if r == "" then
      error "Server closed"
    end
    return f(last .. r)
  end

  return function()
    while true do
      local result
      result, last = try_recv(id, last)
      if result then
        return result
      end
      coroutine.yield()
    end
  end
end

--- game server

--- send data with 2byte lenth header and 4 byte session id
function M.send_request(id, v, session)
  local size    = #v + 4
  local package = string.pack(">I2", size) .. v .. string.pack(">I4", session)
  socket.send(id, package)
  return v, session
end

function M.recv_response(v)
  local size                 = #v - 5
  local content, ok, session = string.unpack("c" .. tostring(size) .. "B>I4", v)
  return ok ~= 0, content, session
end

local function unpack_package(text)
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

function M.send_package(fd, pack)
  local package = string.pack(">s2", pack)
  socket.send(fd, package)
end

M.writeline = writeline
function M.unpacker_line(id)
  return unpack_f(unpack_line, id)
end
function M.unpacker_package(id)
  return unpack_f(unpack_package, id)
end

return M
