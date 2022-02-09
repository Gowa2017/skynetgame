local dbproxy = require("dbproxy")
local skynet  = require("skynet")

local handler = {}

local stmt   
---@param db MySQL
function handler.register(db, username, password)
  local sql = "insert into account(username, password) values(?,?)"
  if not stmt then
    stmt = db:prepare(sql)
  end
  return db:execute(stmt, username, password)

end

dbproxy.mysql({
  host     = "localhost",
  user     = "root",
  database = "mud",
  password = "wouinibaba",
}, handler)
