local dbproxy = require("dbproxy")

local handler = {}

function handler.register(db, username, password)
  local ok, err, r = db["account"]:safe_insert({
    username = username,
    password = password,
  })
  return ok, ok and r or err
end

dbproxy.mongo({
  host     = "127.0.0.1",
  port     = 27017,
  username = "root",
  password = "wouinibaba",
  db       = "mud",
}, handler)
