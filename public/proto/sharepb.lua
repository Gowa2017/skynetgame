local file = "public/proto/proto.pb"
local f    = io.open(file, "rb")
local r    = f:read("a")
return { schema = r }
