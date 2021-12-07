local skynet  = require("skynet")
require "skynet.manager"
local LOG     = require("go.logger")
local message = require("conf.message")

local mongo   = require("skynet.db.mongo")

local db     
local CMD     = {}
function CMD.start(conf)
  db = assert(mongo.client(conf):getDB(conf.authdb), string.format(
                "Connect to db (%s,%s) failed", conf.host, conf.authdb))
end

local ACTION  = {}

function ACTION.insert(t, doc)
  return db:getCollection(t):safe_insert(doc)
end

function ACTION.update(t, condtion, value)
  return db:getCollection(t):safe_update(condtion, { ["$set"] = value })
end

function ACTION.find(t, q, s)
  local iter = db:getCollection(t):find(q, s)
  local r    = {}
  while iter:hasNext() do
    r[#r + 1] = iter:next()
  end
  return r
end

function ACTION.findOne(t, q, s)
  return db:getCollection(t):findOne(q, s)
end

function ACTION.delete(t, s)
  return db:getCollection(t):safe_delete(s)
end

skynet.register_protocol(message.db)
skynet.dispatch("lua", function(session, source, cmd, ...)
  skynet.retpack(CMD[cmd](...))
end)
skynet.dispatch("db", function(session, source, cmd, ...)
  skynet.retpack(ACTION[cmd](...))
end)
skynet.start(function()
end)
