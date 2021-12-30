package.cpath = "./skynet/luaclib/?.so"
local socket = require("client.socket")

local M      = {}

--- login server
function M.writeline(fd, text)
  socket.send(fd, text .. "\n")
end
function M.unpack_line(text)
  local from = text:find("\n", 1, true)
  if from then
    return text:sub(1, from - 1), text:sub(from + 1)
  end
  return nil, text
end

return M
