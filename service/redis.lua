local redisproxy = require("redisproxy")

local function handler(...)
  print(...)
end

redisproxy.connect({ host = "localhost", auth = "wouinibaba" }, handler)
