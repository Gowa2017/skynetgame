local socket = require("client.socket")

---Unpack function generator.
---In a endless loop:
---first try to call unpack function to unpack remain data, return a package if successed, or
---try to read data from socket, if no data on socket, return nil and the remain data; if readed data is space, report server closed; or
---concate remain data and readed data, then call unpack function.
---@param f any
---@param id any
---@return function
return function(f, id)
  local last = ""
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
