local service = require("go.service")
local LOG     = require("go.logger")

local mongo   = require("skynet.db.mongo")

local db     
local CMD     = {}
function CMD.start(conf) db = mongo.client(conf):getDB(conf.authdb) end

local ACTION  = {}

function ACTION.insert(t, doc) return db:getCollection(t):safe_insert(doc) end

function ACTION.update(t, condtion, value)
  return db:getCollection(t):safe_update(condtion, { ["$set"] = value })
end

function ACTION.find(t, q, s)
  local iter = db:getCollection(t):find(q, s)
  local r    = {}
  while iter:hasNext() do r[#r + 1] = iter:next() end
  return r
end

function ACTION.findOne(t, q, s) return db:getCollection(t):findOne(q, s) end

function ACTION.delete(t, s) return db:getCollection(t):safe_delete(s) end

service.setMessageCmds("lua", CMD)
service.enableMessage("db")
service.setMessageCmds("db", ACTION)
service.start()
